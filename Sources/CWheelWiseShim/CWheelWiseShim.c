#include "include/CWheelWiseShim.h"

void WWEventTapEnable(CFMachPortRef tap, bool enable) {
    CGEventTapEnable(tap, enable);
}
