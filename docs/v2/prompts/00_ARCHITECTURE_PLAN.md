# Prompt: deep SourceV2 architecture and execution plan

Copy the text below into a dedicated high-effort Codex task rooted at
`/Users/grimreaper31/Desktop/Dev/MHGA`.

```text
Your task is to produce the complete evidence-backed architecture and execution
plan for Server-Host V2. This is a planning and reverse-engineering task, not an
implementation task. Do not add SourceV2 runtime code or change legacy gameplay
behavior in this task.

Workspace:
/Users/grimreaper31/Desktop/Dev/MHGA

Project:
/Users/grimreaper31/Desktop/Dev/MHGA/Server-Host

First read every file under Server-Host/docs/v2 in the mandatory order from
docs/v2/README.md. Treat HISTORY.md, PROJECT.md, RULES.md and WORKFLOW.md as user
requirements, not optional suggestions.

The user has explicitly selected a separate V2 architecture. The current legacy
implementation is a research source and regression reference, not the structure
to continue. Preserve it.

Sishen requirement:
Treat Sishen as the primary example of how this UE mod code should be organized
and written. Do not skim it. Study all relevant implementations, including its
UE core, containers, names/strings, ScriptCore, static classes, functions,
ProcessEvent wrappers, offsets, memory utilities, startup and hook organization.
Explain precisely which patterns should be adopted, adapted, or rejected for
V2. Sishen is a serious code-pattern authority, but its old offsets, signatures
and ABI must never be copied as truth for ShooterGame 1.10280.

Also deeply inspect:
- the entire current Server-Host source and build layout;
- Dragon/ProjDragon, especially its generated-SDK usage and typed field access;
- both current FreshSDK dumps under Server-Host/Reference/FreshSDK;
- Server-Host/Reference/NetDriverDefinitions-1.10280.md;
- Extra_For_Host/SEA_host_guide.md;
- the preserved legacy 0.2.11 deb, using strings/symbols/disassembly only as a
  behavior map, without pretending its source was recovered;
- /Users/grimreaper31/Desktop/Dev/extra/engines/UE4.17 where engine behavior is
  relevant.

Use exact current binary analysis whenever it is needed to distinguish a real
contract from an architectural assumption. IDA MCP is available. If the wrong
database is open or no database is available, ask the user to open exactly:
- Extra_For_Host/110280.i64 for current iOS ShooterGame;
- Extra_For_Host/SEAServerManager.dylib.i64 for SEA client-manager logic;
- the Android LibUE database after its exact path is supplied.

You may spend substantial time following decompilation, xrefs, callers, virtual
dispatch and state mutations. Do not stop at the first plausible pseudocode.
However, do not attempt to reverse every future administration feature during
this architecture task. Determine the boundaries and create an explicit ABI/RE
backlog for contracts that should be proven only when their workflow becomes
active.

Required analysis:

1. Legacy anatomy
   - map every current Server-Host subsystem and dependency;
   - identify responsibilities mixed inside HostingRuntime.mm/.h;
   - classify code as confirmed behavior, useful infrastructure, diagnostic,
     experimental, rejected, or unknown;
   - map user-visible behavior to implementation modules;
   - identify hot paths, raw memory boundaries, thread transitions and UObject
     lifetime risks;
   - compare current source behavior to evidence available from 0.2.11.

2. Reference analysis
   - produce a concrete Sishen pattern map with source file/function examples;
   - produce a Dragon pattern map;
   - inventory the exact FreshSDK files/classes/functions needed for the
     near-term hosting workflows;
   - explain which FreshSDK code can be adapted directly and which generated
     code should be reduced into a curated V2 layer;
   - define source precedence and conflict handling.

3. Complete SourceV2 architecture
   Design a full but dependency-controlled structure for at least:
   - UE primitive and container types;
   - FName/FNamePool and FString ownership/lifetime;
   - UObject array, weak identity, UClass/UFunction/FProperty reflection;
   - typed engine and ShooterGame classes/views;
   - generated/reflected/native binding layers;
   - build profiles, signatures, vtable bindings and runtime validation;
   - platform-specific image/memory/resolver facilities;
   - isolated hook manager and platform hook backends;
   - game-thread command dispatcher;
   - runtime context and world/driver lifecycle;
   - HostService, ClientService and PlayerJoinService state machines;
   - logging, crash breadcrumbs, snapshots and developer diagnostics;
   - future SaveService and AdministrationService boundaries;
   - ImGui UI boundaries;
   - test seams, fake/static tests where possible, and device gates.

For every proposed directory, class and important interface specify:
   - responsibility;
   - allowed dependencies;
   - forbidden dependencies;
   - ownership/lifetime;
   - thread requirements;
   - whether it contains raw ABI access;
   - relevant legacy source to migrate or reject;
   - relevant Sishen/Dragon pattern;
   - evidence required before implementation.

4. UE type growth strategy
   Do not freeze an artificially tiny list. Start with the types required by the
   first host workflows, including FName, FString, TArray, weak pointers,
   UObject, UClass, UFunction and their supporting structures, then define how
   new types/classes/functions are added safely as later workflows require them.
   Include static assertions, reflection checks, build profiles and code review
   gates. Prevent arbitrary raw fields from leaking into feature code.

5. Hook and GetNetMode design
   - separate hook transport from hook policy;
   - analyze current hardware-breakpoint/trampoline risks;
   - design inert observer hooks before behavior-changing hooks;
   - define a GetNetMode investigation plan that maps callers and separates
     replication behavior from render/weather/world behavior;
   - do not bless caller-RVA whitelisting as production architecture without
     evidence;
   - define how V2 can replace the current broad forced-dedicated policy with the
     closest game-native initialization path.

6. Migration and gates
   - create a migration map from legacy to V2 without copying the monolith;
   - preserve known control artifacts;
   - define small, ordered iOS gates from typed core through stable gameplay;
   - keep Android/VPS as a short deferred direction only;
   - specify exact entry/exit criteria and required user device tests for each
     near-term gate;
   - identify which steps are pure refactor, static validation, IDA research,
     local build, or device validation.

Required outputs in Server-Host/docs/v2:

- ARCHITECTURE.md — full module tree, dependency diagram and interfaces;
- MIGRATION_MAP.md — legacy-to-V2 disposition by subsystem/function;
- ABI_BACKLOG.md — known and missing contracts, evidence source and priority;
- update ROADMAP.md with the approved level of detail;
- update EVIDENCE.md with newly established facts and conflicts;
- update STATUS.md with what was completed and the next bounded workflow;
- update HISTORY.md only if the analysis changes an important earlier
  conclusion or requirement.

ARCHITECTURE.md must include a Mermaid dependency diagram and a proposed build
target/file list. It must be detailed enough that the first implementation task
does not need to redesign the core.

Do not create a large speculative API merely for future completeness. A module
may be planned for the future, but concrete fields/functions enter the typed
core only when a workflow needs them and their current contract is evidenced.

Before finishing:
- re-read RULES.md and audit the plan against every rule;
- list unresolved questions and exactly which IDA database/log/device test would
  answer each one;
- clearly distinguish facts, design decisions and hypotheses;
- provide a concise recommended first implementation workflow.
```

