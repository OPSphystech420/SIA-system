/* * * * * * * * * * * * * * * * * * *
 * * CGPError.h  * * * * * * * * * * *
 * * CGuardProbe * * * * * * * * * * *
 * * * * * * * * * * * * * * * * * * *
 * * Made by OPSphystech420 2024 (c) *
 * * * * * * * * * * * * * * * * * * *
 * * * * * * * * * * * * * * * * * * */

#ifndef CGPError_h
#define CGPError_h

#include <string>

#include <cstdio>

enum class CGPErrorCode {
    None,
    Allocation_Fail,
    Binary_Not_Found,
    Segment_Not_Found,
    Invalid_Argument,
    VMRead_Fail,
    VMWrite_Fail,
    VMProtect_Fail,
    VMDeallocate_Fail,
    VMQuery_Fail,
    Invalid_State,
    // ...
};

struct CGPError {
    CGPErrorCode code;
    std::string message;

    CGPError(CGPErrorCode c = CGPErrorCode::None, const std::string& msg = "")
        : code(c), message(msg) {}
};

/* Error Handler Class */
class CGPErrorHandler {
protected:
    mutable CGPError error_;

public:
    const CGPError& GetError() const noexcept { return error_; }
    void ClearError() noexcept { error_ = CGPError(); }
    bool IsValid() const noexcept { return error_.code == CGPErrorCode::None; }

    void SetError(CGPErrorCode code, const std::string& message) const noexcept {
        error_.code = code;
        error_.message = message;

        std::fprintf(stderr, "[ServerHost][CGPMemory] error %d: %s\n",
                     static_cast<int>(code), message.c_str());
    }
};

#endif /* CGPError_h */
