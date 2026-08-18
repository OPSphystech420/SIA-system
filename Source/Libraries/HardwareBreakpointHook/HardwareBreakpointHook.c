#include "HardwareBreakpointHook.h"

#include "mach_excServer.h"

#include <mach/mach.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/sysctl.h>

enum { ServerHostMaximumHardwareHooks = 6 };

struct ServerHostHardwareHook
{
    uintptr_t Target;
    uintptr_t Replacement;
};

static mach_port_t ServerHostExceptionPort = MACH_PORT_NULL;
static struct ServerHostHardwareHook
    ServerHostHardwareHooks[ServerHostMaximumHardwareHooks];
static int ServerHostActiveHardwareHooks = 0;

kern_return_t catch_mach_exception_raise(
    mach_port_t ExceptionPort, mach_port_t Thread, mach_port_t Task,
    exception_type_t Exception, mach_exception_data_t Code,
    mach_msg_type_number_t CodeCount)
{
    (void)ExceptionPort; (void)Thread; (void)Task; (void)Exception;
    (void)Code; (void)CodeCount;
    return KERN_FAILURE;
}

kern_return_t catch_mach_exception_raise_state_identity(
    mach_port_t ExceptionPort, mach_port_t Thread, mach_port_t Task,
    exception_type_t Exception, mach_exception_data_t Code,
    mach_msg_type_number_t CodeCount, int* Flavor,
    thread_state_t OldState, mach_msg_type_number_t OldStateCount,
    thread_state_t NewState, mach_msg_type_number_t* NewStateCount)
{
    (void)ExceptionPort; (void)Thread; (void)Task; (void)Exception;
    (void)Code; (void)CodeCount; (void)Flavor; (void)OldState;
    (void)OldStateCount; (void)NewState; (void)NewStateCount;
    return KERN_FAILURE;
}

kern_return_t catch_mach_exception_raise_state(
    mach_port_t ExceptionPort, exception_type_t Exception,
    const mach_exception_data_t Code, mach_msg_type_number_t CodeCount,
    int* Flavor, const thread_state_t OldState,
    mach_msg_type_number_t OldStateCount, thread_state_t NewState,
    mach_msg_type_number_t* NewStateCount)
{
    (void)ExceptionPort; (void)Exception; (void)Code; (void)CodeCount;
    (void)Flavor;
    const arm_thread_state64_t* Old =
        (const arm_thread_state64_t*)OldState;
    arm_thread_state64_t* New = (arm_thread_state64_t*)NewState;
    const uintptr_t ProgramCounter = arm_thread_state64_get_pc(*Old);

    for (int Index = 0; Index < ServerHostActiveHardwareHooks; ++Index)
    {
        if (ServerHostHardwareHooks[Index].Target != ProgramCounter)
            continue;
        *New = *Old;
        *NewStateCount = OldStateCount;
        arm_thread_state64_set_pc_fptr(
            *New, ServerHostHardwareHooks[Index].Replacement);
        return KERN_SUCCESS;
    }
    return KERN_FAILURE;
}

static void* ServerHostExceptionServerMain(void* Context)
{
    (void)Context;
    (void)mach_msg_server(mach_exc_server,
        sizeof(union __RequestUnion__catch_mach_exc_subsystem),
        ServerHostExceptionPort, MACH_MSG_OPTION_NONE);
    return NULL;
}

bool ServerHostInstallHardwareHooks(void* Targets[], void* Replacements[],
                                    int Count)
{
    if (!Targets || !Replacements || Count <= 0
        || Count > ServerHostMaximumHardwareHooks
        || ServerHostActiveHardwareHooks != 0)
        return false;

    int AvailableBreakpoints = 0;
    size_t BreakpointSize = sizeof(AvailableBreakpoints);
    if (sysctlbyname("hw.optional.breakpoint", &AvailableBreakpoints,
                     &BreakpointSize, NULL, 0) != 0
        || AvailableBreakpoints < Count)
        return false;

    for (int Index = 0; Index < Count; ++Index)
    {
        if (!Targets[Index] || !Replacements[Index])
            return false;
        ServerHostHardwareHooks[Index].Target =
            (uintptr_t)Targets[Index];
        ServerHostHardwareHooks[Index].Replacement =
            (uintptr_t)Replacements[Index];
    }

    kern_return_t Result = mach_port_allocate(mach_task_self(),
        MACH_PORT_RIGHT_RECEIVE, &ServerHostExceptionPort);
    if (Result != KERN_SUCCESS)
        return false;
    Result = mach_port_insert_right(mach_task_self(),
        ServerHostExceptionPort, ServerHostExceptionPort,
        MACH_MSG_TYPE_MAKE_SEND);
    if (Result != KERN_SUCCESS)
        return false;
    Result = task_set_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT,
        ServerHostExceptionPort, EXCEPTION_STATE | MACH_EXCEPTION_CODES,
        ARM_THREAD_STATE64);
    if (Result != KERN_SUCCESS)
        return false;

    pthread_t ExceptionThread;
    if (pthread_create(&ExceptionThread, NULL,
                       ServerHostExceptionServerMain, NULL) != 0)
        return false;
    pthread_detach(ExceptionThread);

    arm_debug_state64_t DebugState = {0};
    for (int Index = 0; Index < Count; ++Index)
    {
        DebugState.__bvr[Index] = ServerHostHardwareHooks[Index].Target;
        DebugState.__bcr[Index] = 0x1e5;
    }
    ServerHostActiveHardwareHooks = Count;

    if (task_set_state(mach_task_self(), ARM_DEBUG_STATE64,
            (thread_state_t)&DebugState,
            ARM_DEBUG_STATE64_COUNT) != KERN_SUCCESS)
    {
        ServerHostActiveHardwareHooks = 0;
        return false;
    }

    thread_act_array_t Threads = NULL;
    mach_msg_type_number_t ThreadCount = 0;
    if (task_threads(mach_task_self(), &Threads, &ThreadCount)
        != KERN_SUCCESS)
        return true;

    for (mach_msg_type_number_t Index = 0; Index < ThreadCount; ++Index)
        (void)thread_set_state(Threads[Index], ARM_DEBUG_STATE64,
            (thread_state_t)&DebugState, ARM_DEBUG_STATE64_COUNT);
    for (mach_msg_type_number_t Index = 0; Index < ThreadCount; ++Index)
        mach_port_deallocate(mach_task_self(), Threads[Index]);
    vm_deallocate(mach_task_self(), (vm_address_t)Threads,
                  (vm_size_t)ThreadCount * sizeof(*Threads));

    // task_set_state above is the authoritative installation result. A thread
    // can disappear while task_threads is being enumerated; that race must not
    // clear the routing table while another thread already has the breakpoint.
    // The post-Listen direct-call health check proves the UE game thread path.
    return true;
}
