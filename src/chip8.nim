import streams, strutils, random

var
  delay_timer, sound_timer: uint8
  memory: array[4096, uint8]
  V: array[16, uint8]
  index, pc, sp, opcode: uint16
  stack, key: array[16, uint16]
  display: array[2048, uint8] # 64x32
  drawFlag = false

const chip8_fontset = [
  0xF0'u8, 0x90, 0x90, 0x90, 0xF0, # 0
  0x20, 0x60, 0x20, 0x20, 0x70,    # 1
  0xF0, 0x10, 0xF0, 0x80, 0xF0,    # 2
  0xF0, 0x10, 0xF0, 0x10, 0xF0,    # 3
  0x90, 0x90, 0xF0, 0x10, 0x10,    # 4
  0xF0, 0x80, 0xF0, 0x10, 0xF0,    # 5
  0xF0, 0x80, 0xF0, 0x90, 0xF0,    # 6
  0xF0, 0x10, 0x20, 0x40, 0x40,    # 7
  0xF0, 0x90, 0xF0, 0x90, 0xF0,    # 8
  0xF0, 0x90, 0xF0, 0x10, 0xF0,    # 9
  0xF0, 0x90, 0xF0, 0x90, 0x90,    # A
  0xE0, 0x90, 0xE0, 0x90, 0xE0,    # B
  0xF0, 0x80, 0x80, 0x80, 0xF0,    # C
  0xE0, 0x90, 0x90, 0x90, 0xE0,    # D
  0xF0, 0x80, 0xF0, 0x80, 0xF0,    # E
  0xF0, 0x80, 0xF0, 0x80, 0x80]    # F

proc initialize =
  pc = 0x200
  opcode = 0
  index = 0
  sp = 0
  sound_timer = 0
  delay_timer = 0

  for i in 0..4095:
    memory[i] = 0

  for i in 0..2047:
    display[i] = 0

  for i in 0..15:
    V[i] = 0
    stack[i] = 0

  for i in 0..79:
    memory[i] = chip8_fontset[i]


proc updateTimers =
  if delay_timer > 0'u8:
    dec delay_timer
  if sound_timer > 0'u8:
    if sound_timer == 1'u8:
      #TODO: BEEP
      discard
    dec sound_timer

proc emulateCycle =
  opcode = memory[pc]
  opcode = opcode shl 8 or memory[pc + 1]
  let x = (opcode and 0x0F00) shr 8
  let y = (opcode and 0x00F0) shr 4

  case opcode and 0xF000:
    of 0x0000:
      case opcode and 0x000F:
        of 0x0000:
          for i in 0..2047:
            display[i] = 0
          drawFlag = true
          pc += 2

        of 0x000E:
          dec sp
          pc = stack[sp]
        else: 
          echo "Error: Unknown opcode: " & opcode.toHex
          pc += 2

    of 0x1000:
      pc = opcode and 0x0FFF

    of 0x2000:
      stack[sp] = pc
      inc sp
      pc = opcode and 0x0FFF

    of 0x3000:
      if V[x] == uint8(opcode and 0x00FF):
        pc += 4
      else:
        pc += 2
    
    of 0x4000:
      if V[x] != uint8(opcode and 0x00FF):
        pc += 4
      else:
        pc += 2

    of 0x5000:
      if V[x] == V[y]:
        pc += 4
      else:
        pc += 2

    of 0x6000:
      V[x] = uint8(opcode and 0x00FF)
      opcode += 2

    of 0x7000:
      V[x] += uint8(opcode and 0x00FF)
      pc += 2

    of 0x8000:
      case opcode and 0x000F:
        of 0x0000:
          V[x] = V[y]
          opcode += 2
        
        of 0x0001:
          V[x] = V[x] or V[y]
          opcode += 2

        of 0x0002:
          V[x] = V[x] and V[y]
          opcode += 2
      
        of 0x0003:
          V[x] = V[x] xor V[y]
          opcode += 2

        of 0x0004:
          if V[y] > (0xFF'u8 - V[x]):
            V[0xF] = 1
            V[x] += V[y] - 0xFF
          else:
            V[0xF] = 0
            V[x] += V[y]
          pc += 2

        of 0x0005:
          if V[x] > V[y]:
            V[0xF] = 1
            V[x] -= V[y]
          else:
            V[0xF] = 0
            V[x] -= V[y] + 0xFF
          pc += 2

        of 0x0006:
          V[0xF] = V[x] and 0x1
          V[x] = V[x] shr 1
          pc += 2

        of 0x0007:
          if V[x] > V[y]:
            V[0xF] = 0
            V[x] = V[y] - V[x] + 0xFF
          else:
            V[0xF] = 1
            V[x] = V[y] - V[x]
          pc += 2

        of 0x000E:
          V[0xF] = V[x] and 0x80
          V[x] = V[x] shl 1
          pc += 2

        else: 
          echo "Error: Unknown opcode: " & opcode.toHex
          pc += 2
    of 0x9000:
      if V[x] != V[y]:
        pc += 4

    of 0xA000:
      index = opcode and 0x0FFF
      pc += 2

    of 0xB000:
      pc = (opcode and 0x0FFF) + V[0]
    
    of 0xC000:
      V[x] = uint8(rand(255)) and 0x00FF
      pc += 2

    of 0xD000:
      let x = V[x]
      let y = V[y]
      let h = opcode and 0x000F
      V[0xF] = 0
      for row in 0'u8..uint8(h):
        let pixel = memory[index + row]
        for column in 0'u8..7:
          if ((pixel and 0x80) shr column) != 0:
            let i = x + column + ((y + row) * 64)
            if display[i] == 1:
              V[0xF] = 1
            display[i] = display[i] xor 1
      drawFlag = true
      pc += 2

    of 0xE000:
      case opcode and 0x00FF:
        of 0x009E:
          if key[x] != 0:
            pc += 4
          else:
            pc += 2

        of 0x00A1:
          if key[x] != 1:
            pc += 4
          else:
            pc += 2

        else: 
          echo "Error: Unknown opcode: " & opcode.toHex
          pc += 2

    of 0xF000:
      case opcode and 0x00FF:
        of 0x0007:
          V[x] = delay_timer
          pc += 2

        of 0x000A:
          block wait_key:
            while true:
              for i in key:
                if key[i] == 1:
                  V[x] = uint8(i)
                  break wait_key
          pc += 2
        
        of 0x0015:
          delay_timer = V[x]
          pc += 2
        
        of 0x0018:
          sound_timer = V[x]
          pc += 2
        
        of 0x001E:
          index += V[x]
          pc += 2
        
        of 0x0029:
          index = V[x] * 5
          pc += 2
        
        of 0x0033:
          memory[index] = V[x] div 100
          memory[index + 1] = (V[x] div 10) mod 10
          memory[index + 2] = (V[x] div 100) mod 10
          pc += 2

        of 0x0055:
          for i in 0'u16..uint16(x):
            memory[index + uint16(i)] = V[i]
          pc += 2
        
        of 0x0065:
          for i in 0..0xF:
            V[i] = memory[index + uint16(i)]
          pc += 2

        else:
          echo "Error: Unknown opcode: " & opcode.toHex
          pc += 2
    else:
      echo "Error: Unknown opcode: " & opcode.toHex
      pc += 2

  updateTimers()

proc loadROM(file: string) =
  var f = newFileStream(file, fmRead)
  var i = 512
  try:
    while not f.atEnd:
      memory[i] = f.readUint8()
      inc i
  except IndexError:
    echo "Error: File too large to read"
    
when isMainModule:
  initialize()
  loadROM("TETRIS")
  while true:
    emulateCycle()