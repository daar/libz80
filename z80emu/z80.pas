{ =============================================================================
 *  libz80 - Z80 emulation library
 * =============================================================================
 *
 * (C) Gabriel Gambetta (gabriel.gambetta@gmail.com) 2000 - 2012
 *
 * Version 2.1.0
 *
 * -----------------------------------------------------------------------------
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
  }

{
  Automatically converted by H2Pas 1.0.0 from z80.h
  The following command line parameters were used:
    -D
    -P
    -p
    -l
    libz80
    -T
    -v
    -o
    z80.pas
    z80.h
}

unit z80;

{$mode objfpc}

interface

type
  {* Function type to emulate data read.  }

  TZ80DataIn = function(param: longint; address: word): byte; cdecl;
  {* Function type to emulate data write.  }

  TZ80DataOut = procedure(param: longint; address: word; Data: byte); cdecl;
  {* 
   * A Z80 register set.
   * An union is used since we want independent access to the high and low bytes of the 16-bit registers.
    }
  {* Word registers.  }
  {* Byte registers. Note that SP can't be accesed partially.  }

  PZ80Regs = ^TZ80Regs;
  TZ80Regs = record
    case longint of
      0: (wr: record
          AF: word;
          BC: word;
          DE: word;
          HL: word;
          IX: word;
          IY: word;
          SP: word;
        end);
      1: (br: record
          F: byte;
          A: byte;
          C: byte;
          B: byte;
          E: byte;
          D: byte;
          L: byte;
          H: byte;
          IXl: byte;
          IXh: byte;
          IYl: byte;
          IYh: byte;
        end);
  end;

  {* The Z80 flags  }
  PZ80Flags = ^TZ80Flags;
  TZ80Flags = (
    F_C  :=   1, {*< Carry  }
    F_N  :=   2, {*< Sub / Add  }
    F_PV :=   4, {*< Parity / Overflow  }
    F_3  :=   8, {*< Reserved  }
    F_H  :=  16, {*< Half carry  }
    F_5  :=  32, {*< Reserved  }
    F_Z  :=  64, {*< Zero  }
    F_S  := 128  {*< Sign  }
  );

  {* A Z80 execution context.  }
  {*< Main register set (R)  }
  {*< Alternate register set (R')  }
  {*< Program counter  }
  {*< Refresh  }
  {*< Interrupt Flipflop 1  }
  {*< Interrupt Flipflop 2  }
  {*< Instruction mode  }
  { Below are implementation details which may change without
     * warning; they should not be relied upon by any user of this
     * library.
      }
  { If true, an NMI has been requested.  }
  { If true, a maskable interrupt has been requested.  }
  { If true, defer checking maskable interrupts for one
     * instruction.  This is used to keep an interrupt from happening
     * immediately after an IE instruction.  }
  { When a maskable interrupt has been requested, the interrupt
     * vector.  For interrupt mode 1, it's the opcode to execute.  For
     * interrupt mode 2, it's the LSB of the interrupt vector address.
     * Not used for interrupt mode 0.
      }
  { If true, then execute the opcode in int_vector.  }

  PZ80Context = ^TZ80Context;

  TZ80Context = record
    R1: TZ80Regs;
    R2: TZ80Regs;
    PC: word;
    R: byte;
    I: byte;
    IFF1: byte;
    IFF2: byte;
    IM: byte;
    memRead: TZ80DataIn;
    memWrite: TZ80DataOut;
    memParam: longint;
    ioRead: TZ80DataIn;
    ioWrite: TZ80DataOut;
    ioParam: longint;
    halted: byte;
    tstates: dword;
    nmi_req: byte;
    int_req: byte;
    defer_int: byte;
    int_vector: byte;
    exec_int_vector: byte;
  end;
{* Execute the next instruction.  }

var
  Z80Execute: procedure(var ctx: TZ80Context); cdecl;
  {* Execute enough instructions to use at least tstates cycles.
   * Returns the number of tstates actually executed.  Note: Resets
   * ctx->tstates. }
  Z80ExecuteTStates: function(var ctx: TZ80Context; tstates: dword): dword; cdecl;
  {* Decode the next instruction to be executed.
   * dump and decode can be NULL if such information is not needed
   *
   * @param dump A buffer which receives the hex dump
   * @param decode A buffer which receives the decoded instruction
    }
  Z80Debug: procedure(var ctx: TZ80Context; dump: PChar; decode: PChar); cdecl;
  {* Resets the processor.  }
  Z80RESET: procedure(var ctx: TZ80Context); cdecl;
  {* Generates a hardware interrupt.
   * Some interrupt modes read a value from the data bus; this value must be provided in this function call, even
   * if the processor ignores that value in the current interrupt mode.
   *
   * @param value The value to read from the data bus
    }
  Z80INT: procedure(var ctx: TZ80Context; Value: byte); cdecl;
  {* Generates a non-maskable interrupt.  }
  Z80NMI: procedure(var ctx: TZ80Context); cdecl;
{$endif}

implementation

uses
  SysUtils, dynlibs;

var
  hlib: tlibhandle;


procedure Freez80;
begin
  FreeLibrary(hlib);
  Z80Execute := nil;
  Z80ExecuteTStates := nil;
  Z80Debug := nil;
  Z80RESET := nil;
  Z80INT := nil;
  Z80NMI := nil;
end;


procedure Loadz80(lib: PChar);
begin
  hlib := LoadLibrary(lib);
  if hlib = 0 then
    raise Exception.Create(format('Could not load library: %s', [lib]));

  pointer(Z80Execute) := GetProcAddress(hlib, 'Z80Execute');
  pointer(Z80ExecuteTStates) := GetProcAddress(hlib, 'Z80ExecuteTStates');
  pointer(Z80Debug) := GetProcAddress(hlib, 'Z80Debug');
  pointer(Z80RESET) := GetProcAddress(hlib, 'Z80RESET');
  pointer(Z80INT) := GetProcAddress(hlib, 'Z80INT');
  pointer(Z80NMI) := GetProcAddress(hlib, 'Z80NMI');
end;


initialization
  Loadz80('../libz80.so');

finalization
  Freez80;

end.
