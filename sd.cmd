
@REM Compile RAM version of ufm. This will incbin launch.prg
cl65 -Ln bin/symbols-test.txt -t cx16 -C c:/x16/XSD/cfg/cx16.cfg  -u __EXEHDR__ -o bin/test.prg test.s 
@REM Run the emulator with the custom rom image and fm.prg loaded into memory
cd..
x16emu -debug -startin c:\x16 -rom romfm.bin -prg xsd/bin/test.prg -hostfsdev 9 -sdcard 2part.img 
cd xsd

    
@REM -hostfsdev 9 -sdcard 2part.img


