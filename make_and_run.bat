@ECHO OFF
nasm "%1" -f bin -o "floppy.img"
copy "floppy.img" "pastimages\%1.img"
start "" "bochs.exe" -f bochsrc.bxrc -q
