#include "HostMenu.hpp"

#import <UIKit/UIKit.h>

#include "../ImGui/imgui.h"
#include "../Source/Hosting/HostingRuntime.h"

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <set>
#include <string>
#include <utility>
#include <vector>

#ifndef SERVERHOST_DEVELOPER_UI
#define SERVERHOST_DEVELOPER_UI 0
#endif

#ifndef SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE
#define SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE 0
#endif

namespace
{
    char HostPassword[96] = "";
    int HostPort = 7777;

    char ClientHost[192] = "127.0.0.1";
    char ClientPassword[96] = "";
    int ClientPort = 7777;

    char BroadcastMessage[257] = "";
    char KickReason[144] = "Removed by local host administrator";
    std::string SelectedPlayerId;
    std::string PendingKickId;

    UIViewController* TopViewController()
    {
        UIWindow* Window = nil;
        for (UIScene* Scene in UIApplication.sharedApplication.connectedScenes)
        {
            if (![Scene isKindOfClass:UIWindowScene.class])
                continue;
            for (UIWindow* Candidate in ((UIWindowScene*)Scene).windows)
            {
                if (!Window || Candidate.isKeyWindow)
                    Window = Candidate;
            }
        }

        UIViewController* Controller = Window.rootViewController;
        while (Controller.presentedViewController)
            Controller = Controller.presentedViewController;
        return Controller;
    }

    void PromptText(const char* Title, char* Buffer, size_t Capacity,
                    bool Secure = false,
                    UIKeyboardType Keyboard = UIKeyboardTypeDefault)
    {
        if (!Buffer || Capacity == 0)
            return;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController* Presenter = TopViewController();
            if (!Presenter || [Presenter isKindOfClass:UIAlertController.class])
                return;
            UIAlertController* Alert = [UIAlertController
                alertControllerWithTitle:[NSString stringWithUTF8String:Title ?: "Edit"]
                                 message:nil
                          preferredStyle:UIAlertControllerStyleAlert];
            [Alert addTextFieldWithConfigurationHandler:^(UITextField* Field) {
                Field.text = [NSString stringWithUTF8String:Buffer];
                Field.secureTextEntry = Secure;
                Field.keyboardType = Keyboard;
                Field.autocapitalizationType = UITextAutocapitalizationTypeNone;
                Field.autocorrectionType = UITextAutocorrectionTypeNo;
            }];
            [Alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil]];
            [Alert addAction:[UIAlertAction actionWithTitle:@"Apply"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(__unused UIAlertAction* Action) {
                const char* Value = Alert.textFields.firstObject.text.UTF8String ?: "";
                std::strncpy(Buffer, Value, Capacity - 1);
                Buffer[Capacity - 1] = '\0';
            }]];
            [Presenter presentViewController:Alert animated:YES completion:nil];
        });
    }

    bool CopyLogToClipboard(const std::vector<ServerHost::RuntimeLogEntry>& Entries)
    {
        std::string Text;
        for (const ServerHost::RuntimeLogEntry& Entry : Entries)
        {
            Text += Entry.Text;
            Text.push_back('\n');
        }
        NSString* Value = [[NSString alloc]
            initWithBytes:Text.data() length:Text.size()
            encoding:NSUTF8StringEncoding];
        if (!Value)
            return false;
        UIPasteboard.generalPasteboard.string = Value;
        return true;
    }

    bool CopyTextToClipboard(const std::string& Text)
    {
        NSString* Value = [[NSString alloc]
            initWithBytes:Text.data() length:Text.size()
            encoding:NSUTF8StringEncoding];
        if (!Value)
            return false;
        UIPasteboard.generalPasteboard.string = Value;
        return true;
    }

    const char* HostStateName(ServerHost::HostLifecycleState State)
    {
        using S = ServerHost::HostLifecycleState;
        switch (State)
        {
            case S::Disabled: return "Disabled";
            case S::Resolving: return "Resolving";
            case S::Ready: return "Ready";
            case S::HostRequested: return "Host requested";
            case S::PatchingNetDriver: return "Preparing network driver";
            case S::ListenStarting: return "Starting listener";
            case S::Listening: return "Listening";
            case S::AcceptingClients: return "Accepting clients";
            case S::Stopping: return "Stopping";
            case S::Stopped: return "Stopped";
            case S::Failed: return "Failed";
        }
        return "Unknown";
    }

    const char* ClientStateName(ServerHost::ClientLifecycleState State)
    {
        using S = ServerHost::ClientLifecycleState;
        switch (State)
        {
            case S::Disabled: return "Disabled";
            case S::Ready: return "Ready";
            case S::TravelRequested: return "Travel requested";
            case S::Traveling: return "Traveling";
            case S::Connecting: return "Connecting";
            case S::Connected: return "Connected";
            case S::Playing: return "Playing";
            case S::Disconnected: return "Disconnected";
            case S::Failed: return "Failed";
        }
        return "Unknown";
    }

    struct LocalIPv4Address
    {
        std::string Interface;
        std::string Address;
        bool PrivateLAN = false;
        bool LinkLocal = false;
    };

    std::vector<LocalIPv4Address> LocalIPv4Addresses()
    {
        static std::vector<LocalIPv4Address> Cached;
        static std::chrono::steady_clock::time_point LastRefresh{};
        const auto Now = std::chrono::steady_clock::now();
        if (!Cached.empty() && LastRefresh.time_since_epoch().count() != 0
            && Now - LastRefresh < std::chrono::seconds(5))
            return Cached;
        std::set<std::pair<std::string, std::string>> Unique;
        std::vector<LocalIPv4Address> Refreshed;
        ifaddrs* Interfaces = nullptr;
        if (getifaddrs(&Interfaces) == 0)
        {
            for (const ifaddrs* Current = Interfaces; Current; Current = Current->ifa_next)
            {
                if (!Current->ifa_addr || Current->ifa_addr->sa_family != AF_INET
                    || !(Current->ifa_flags & IFF_UP)
                    || (Current->ifa_flags & IFF_LOOPBACK))
                    continue;
                char Address[INET_ADDRSTRLEN]{};
                const sockaddr_in* IPv4 = reinterpret_cast<const sockaddr_in*>(
                    Current->ifa_addr);
                if (inet_ntop(AF_INET, &IPv4->sin_addr, Address, sizeof(Address)))
                {
                    const std::string Interface = Current->ifa_name
                        ? Current->ifa_name : "interface";
                    if (!Unique.emplace(Interface, Address).second)
                        continue;
                    const uint32 HostOrder = ntohl(IPv4->sin_addr.s_addr);
                    const uint8 First = static_cast<uint8>(HostOrder >> 24);
                    const uint8 Second = static_cast<uint8>((HostOrder >> 16) & 0xFF);
                    const bool PrivateLAN = First == 10
                        || (First == 172 && Second >= 16 && Second <= 31)
                        || (First == 192 && Second == 168);
                    const bool LinkLocal = First == 169 && Second == 254;
                    Refreshed.push_back({Interface, Address, PrivateLAN, LinkLocal});
                }
            }
            freeifaddrs(Interfaces);
        }
        std::sort(Refreshed.begin(), Refreshed.end(),
            [](const LocalIPv4Address& Left, const LocalIPv4Address& Right)
            {
                if (Left.PrivateLAN != Right.PrivateLAN)
                    return Left.PrivateLAN > Right.PrivateLAN;
                if (Left.LinkLocal != Right.LinkLocal)
                    return Left.LinkLocal < Right.LinkLocal;
                if (Left.Interface != Right.Interface)
                    return Left.Interface < Right.Interface;
                return Left.Address < Right.Address;
            });
        if (Refreshed.empty())
            Refreshed.push_back({"loopback", "127.0.0.1", false, false});
        Cached = std::move(Refreshed);
        LastRefresh = Now;
        return Cached;
    }

    ImVec4 LogColor(ServerHost::LogLevel Level)
    {
        using L = ServerHost::LogLevel;
        switch (Level)
        {
            case L::Warning: return ImVec4(1.0f, 0.74f, 0.25f, 1.0f);
            case L::Error: return ImVec4(1.0f, 0.35f, 0.35f, 1.0f);
            case L::Debug: return ImVec4(0.55f, 0.72f, 1.0f, 1.0f);
            default: return ImGui::GetStyleColorVec4(ImGuiCol_Text);
        }
    }
}

namespace ServerHost::Menu
{
    void Render()
    {
        HostingRuntime& Runtime = HostingRuntime::Get();
        const RuntimeSnapshot Snapshot = Runtime.Snapshot();

        ImGui::SetNextWindowSize(ImVec2(560.0f, 0.0f), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(24.0f, 90.0f), ImGuiCond_FirstUseEver);
        if (!ImGui::Begin("MHGA Server Host", nullptr,
                          ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_AlwaysAutoResize))
        {
            ImGui::End();
            return;
        }

        ImGui::TextWrapped("%s", Snapshot.Status.c_str());
        if (!Snapshot.LastError.empty())
            ImGui::TextColored(ImVec4(1.0f, 0.35f, 0.35f, 1.0f),
                               "Error: %s", Snapshot.LastError.c_str());
        if (!Snapshot.GameThreadConfirmed)
            ImGui::TextColored(ImVec4(1.0f, 0.74f, 0.25f, 1.0f),
                               "Waiting for the UE game-thread dispatcher");

        if (ImGui::BeginTabBar("ServerHostTabs"))
        {
            if (ImGui::BeginTabItem("Host"))
            {
                ImGui::InputInt("Port", &HostPort);
                HostPort = std::clamp(HostPort, 1, 65535);
                ImGui::InputText("Optional password", HostPassword,
                                 sizeof(HostPassword), ImGuiInputTextFlags_Password);
                ImGui::SameLine();
                if (ImGui::Button("Edit##HostPassword"))
                    PromptText("Optional server password", HostPassword,
                               sizeof(HostPassword), true);

                const bool StartBlocked = Snapshot.Hosting || Snapshot.HostPending
                    || Snapshot.ListenAttemptInProgress
                    || Snapshot.HostState == HostLifecycleState::Stopping;
                if (StartBlocked) ImGui::BeginDisabled();
                if (ImGui::Button("Start server"))
                {
                    // Diagnostic B preserves the exact original GetNetMode
                    // result while retaining the same hook and host path.
                    constexpr bool ForceDedicatedMode =
                        SERVERHOST_DIAGNOSTIC_ORIGINAL_NETMODE == 0;
                    Runtime.RequestHost(HostPort, "", HostPassword,
                                        ForceDedicatedMode, true);
                }
                if (StartBlocked) ImGui::EndDisabled();
                ImGui::SameLine();
                const bool StopBlocked = !Snapshot.Hosting
                    || Snapshot.HostState == HostLifecycleState::Stopping;
                if (StopBlocked) ImGui::BeginDisabled();
                if (ImGui::Button("Save and stop"))
                    Runtime.RequestStop();
                if (StopBlocked) ImGui::EndDisabled();

                ImGui::Separator();
                ImGui::Text("Server status: %s", HostStateName(Snapshot.HostState));
                ImGui::Text("Current world: %s", Snapshot.WorldName.empty()
                    ? "not discovered" : Snapshot.WorldName.c_str());
                ImGui::Text("Connected players: %d", Snapshot.ConnectedClients);
                const int EndpointPort = Snapshot.BoundPort > 0
                    ? Snapshot.BoundPort : HostPort;
                if (Snapshot.Hosting && Snapshot.BoundPort > 0)
                {
                    ImGui::Text("Bound UDP port: %d", Snapshot.BoundPort);
                    if (Snapshot.BoundPort != Snapshot.RequestedPort)
                    {
                        ImGui::TextColored(ImVec4(1.0f, 0.74f, 0.25f, 1.0f),
                            "Requested %d; IP NetDriver selected %d",
                            Snapshot.RequestedPort, Snapshot.BoundPort);
                    }
                }
                ImGui::TextUnformatted("Local/LAN endpoint(s):");
                const std::vector<LocalIPv4Address> LocalAddresses =
                    LocalIPv4Addresses();
                for (std::size_t Index = 0; Index < LocalAddresses.size(); ++Index)
                {
                    const LocalIPv4Address& Entry = LocalAddresses[Index];
                    const std::string Endpoint = Entry.Address + ":"
                        + std::to_string(EndpointPort);
                    const char* Scope = Entry.PrivateLAN ? "private LAN"
                        : (Entry.LinkLocal ? "link-local" : "interface");
                    ImGui::BulletText("%s (%s, %s)", Endpoint.c_str(),
                                      Entry.Interface.c_str(), Scope);
                    ImGui::SameLine();
                    const std::string CopyId = "Copy##Endpoint"
                        + std::to_string(Index);
                    if (ImGui::SmallButton(CopyId.c_str()))
                        CopyTextToClipboard(Endpoint);
                }
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("Client"))
            {
                ImGui::InputText("IP / domain", ClientHost, sizeof(ClientHost));
                ImGui::SameLine();
                if (ImGui::Button("Edit##ClientHost"))
                    PromptText("Server IP or domain", ClientHost,
                               sizeof(ClientHost), false, UIKeyboardTypeURL);
                ImGui::InputInt("Port##Client", &ClientPort);
                ClientPort = std::clamp(ClientPort, 1, 65535);
                ImGui::InputText("Password##Client", ClientPassword,
                                 sizeof(ClientPassword), ImGuiInputTextFlags_Password);
                ImGui::SameLine();
                if (ImGui::Button("Edit##ClientPassword"))
                    PromptText("Server password", ClientPassword,
                               sizeof(ClientPassword), true);

                const bool ConnectBlocked = Snapshot.ClientTravelPending
                    || Snapshot.ClientState == ClientLifecycleState::Connected
                    || Snapshot.ClientState == ClientLifecycleState::Playing;
                if (ConnectBlocked) ImGui::BeginDisabled();
                if (ImGui::Button("Connect"))
                {
                    const std::string Endpoint = std::string(ClientHost) + ":"
                        + std::to_string(ClientPort);
                    Runtime.Join(Endpoint, ClientPassword, false);
                }
                if (ConnectBlocked) ImGui::EndDisabled();

                const bool CanReturn = Snapshot.CurrentRole == Role::Client
                    && (Snapshot.ClientState == ClientLifecycleState::Connected
                        || Snapshot.ClientState == ClientLifecycleState::Playing)
                    && !Snapshot.ClientReturnToMenuPending;
                if (!CanReturn) ImGui::BeginDisabled();
                if (ImGui::Button("Return to menu"))
                    Runtime.RequestReturnToMenu();
                if (!CanReturn) ImGui::EndDisabled();

                ImGui::Separator();
                ImGui::Text("Connection state: %s",
                            ClientStateName(Snapshot.ClientState));
                if (!Snapshot.LastError.empty())
                    ImGui::TextWrapped("Connection error: %s",
                                       Snapshot.LastError.c_str());
                ImGui::EndTabItem();
            }

            if (Snapshot.CurrentRole == Role::Host
                && ImGui::BeginTabItem("Administration"))
            {
                const bool HostReady = Snapshot.Hosting
                    && Snapshot.GameThreadConfirmed;
                if (!HostReady) ImGui::BeginDisabled();

                ImGui::InputText("Broadcast message", BroadcastMessage,
                                 sizeof(BroadcastMessage));
                ImGui::SameLine();
                if (ImGui::Button("Edit##Broadcast"))
                    PromptText("Broadcast message", BroadcastMessage,
                               sizeof(BroadcastMessage));
                if (ImGui::Button("Broadcast"))
                    Runtime.RequestBroadcast(BroadcastMessage);
                ImGui::SameLine();
                if (ImGui::Button("Save world"))
                    Runtime.RequestSaveWorld();

                ImGui::Separator();
                ImGui::TextUnformatted("Remote players");
                const PlayerSummary* SelectedPlayer = nullptr;
                for (const PlayerSummary& Player : Snapshot.Players)
                {
                    const bool Selected = SelectedPlayerId == Player.StableId;
                    const std::string Label = Player.PlayerName + " ["
                        + Player.StateName + "]##" + Player.StableId;
                    if (ImGui::Selectable(Label.c_str(), Selected))
                        SelectedPlayerId = Player.StableId;
                    if (SelectedPlayerId == Player.StableId)
                        SelectedPlayer = &Player;
                }
                if (SelectedPlayer)
                {
                    ImGui::Text("Recovery: %s", SelectedPlayer->Recovery.c_str());
                    ImGui::Text("PlayerDataID: %llu",
                        static_cast<unsigned long long>(SelectedPlayer->PlayerDataId));
                    ImGui::TextWrapped("Identity: %s",
                        SelectedPlayer->PersistentIdentityValue.empty()
                            ? "missing"
                            : SelectedPlayer->PersistentIdentityValue.c_str());
                    ImGui::InputText("Kick reason", KickReason,
                                     sizeof(KickReason));
                    if (ImGui::Button("Kick selected player"))
                    {
                        PendingKickId = SelectedPlayerId;
                        ImGui::OpenPopup("Confirm kick");
                    }
                }
                else if (!SelectedPlayerId.empty())
                {
                    SelectedPlayerId.clear();
                }

                if (ImGui::BeginPopupModal("Confirm kick", nullptr,
                                           ImGuiWindowFlags_AlwaysAutoResize))
                {
                    ImGui::TextUnformatted("Disconnect selected player?");
                    if (ImGui::Button("Confirm##Kick"))
                    {
                        Runtime.RequestKick(PendingKickId, KickReason);
                        PendingKickId.clear();
                        ImGui::CloseCurrentPopup();
                    }
                    ImGui::SameLine();
                    if (ImGui::Button("Cancel##Kick"))
                    {
                        PendingKickId.clear();
                        ImGui::CloseCurrentPopup();
                    }
                    ImGui::EndPopup();
                }

                if (!HostReady) ImGui::EndDisabled();
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("Logs"))
            {
                static bool ShowInfo = true;
                static bool ShowWarnings = true;
                static bool ShowErrors = true;
                static bool ShowDebug = false;
                static bool AutoScroll = true;
                ImGui::Checkbox("Info", &ShowInfo); ImGui::SameLine();
                ImGui::Checkbox("Warning", &ShowWarnings); ImGui::SameLine();
                ImGui::Checkbox("Error", &ShowErrors); ImGui::SameLine();
                ImGui::Checkbox("Debug", &ShowDebug); ImGui::SameLine();
                ImGui::Checkbox("Auto-scroll", &AutoScroll);
                if (ImGui::Button("Clear"))
                    Runtime.ClearLogs();
                ImGui::SameLine();
                if (ImGui::Button("Copy"))
                    CopyLogToClipboard(Snapshot.LogEntries);

                ImGui::BeginChild("RuntimeLogs", ImVec2(520.0f, 240.0f), true);
                const bool WasAtBottom = ImGui::GetScrollY()
                    >= ImGui::GetScrollMaxY() - 4.0f;
                for (const RuntimeLogEntry& Entry : Snapshot.LogEntries)
                {
                    const bool Visible =
                        (Entry.Level == LogLevel::Info && ShowInfo)
                        || (Entry.Level == LogLevel::Warning && ShowWarnings)
                        || (Entry.Level == LogLevel::Error && ShowErrors)
                        || (Entry.Level == LogLevel::Debug && ShowDebug);
                    if (Visible)
                        ImGui::TextColored(LogColor(Entry.Level), "%s",
                                           Entry.Text.c_str());
                }
                if (AutoScroll && WasAtBottom)
                    ImGui::SetScrollHereY(1.0f);
                ImGui::EndChild();
                ImGui::EndTabItem();
            }

            ImGui::EndTabBar();
        }
        ImGui::End();
    }
}
