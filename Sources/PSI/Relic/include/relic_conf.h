//
//  relic_conf.h
//  OpenDrop Base
//
//  Created by Alex - SEEMOO on 16.07.20.
//

#if __aarch64__
#include "relic_conf_arm.h"
#else
#include "relic_conf_x86.h"
#endif
