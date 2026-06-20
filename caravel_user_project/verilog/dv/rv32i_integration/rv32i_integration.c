// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

#include <defs.h>
#include <stub.c>

// RV32I Core Control Offsets
#define RV32I_IMEM_BASE  0x30000000
#define RV32I_DMEM_BASE  0x30002000
#define RV32I_CTRL_BASE  0x30004000

#define RV32I_IMEM(offset) (*(volatile uint32_t*)(RV32I_IMEM_BASE + (offset)))
#define RV32I_DMEM(offset) (*(volatile uint32_t*)(RV32I_DMEM_BASE + (offset)))
#define RV32I_CTRL         (*(volatile uint32_t*)(RV32I_CTRL_BASE))

void main()
{
    // Configure upper 16 GPIOs as outputs for checkbits
    reg_mprj_io_31 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_30 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_29 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_28 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_27 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_26 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_25 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_24 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_23 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_22 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_21 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_20 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_19 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_18 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_17 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_16 = GPIO_MODE_MGMT_STD_OUTPUT;

    // Apply configuration
    reg_mprj_xfer = 1;
    while (reg_mprj_xfer == 1);

    // Initial status
    reg_mprj_datal = 0x00000000;

    // Enable Wishbone
    reg_wb_enable = 1;

    // 1. Hold CPU in reset
    RV32I_CTRL = 0x00000000;

    // 2. Load firmware into IMEM
    // Assembly:
    // addi x1, x0, 5    -> 0x00500093
    // addi x2, x0, 10   -> 0x00a00113
    // add  x3, x1, x2   -> 0x002081b3
    // sw   x3, 0(x0)    -> 0x00302023
    RV32I_IMEM(0)  = 0x00500093; // addi x1, x0, 5
    RV32I_IMEM(4)  = 0x00a00113; // addi x2, x0, 10
    RV32I_IMEM(8)  = 0x002081b3; // add x3, x1, x2
    RV32I_IMEM(12) = 0x00302023; // sw x3, 0(x0)

    // 3. Clear DMEM target address to 0 just in case
    RV32I_DMEM(0) = 0x00000000;

    // 4. Release CPU reset
    RV32I_CTRL = 0x00000001;

    // 5. Wait for CPU to execute instructions (delay loop)
    for (int i = 0; i < 20; i++) {
        __asm__ volatile ("nop");
    }

    // 6. Verify result in DMEM
    uint32_t result = RV32I_DMEM(0);

    if (result == 15) {
        reg_mprj_datal = 0xABBA0000; // Success code in [31:16]
    } else {
        reg_mprj_datal = 0xDEAD0000; // Failure code in [31:16]
    }

    while (1);
}
