#ifndef CWheelWiseShim_h
#define CWheelWiseShim_h

#include <CoreGraphics/CoreGraphics.h>

/// Swift 无法直接调用 CGEventTapEnable（被标记 obsoleted），经由 C shim 调用。
void WWEventTapEnable(CFMachPortRef tap, bool enable);

#endif /* CWheelWiseShim_h */
