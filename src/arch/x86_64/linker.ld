ENTRY(start)

SECTIONS {
  . = 1M;

  .boot :
  {
    /* ensure multiboot header comes first */
    *(.mbheader)
  }

  .text :
  {
    *(.text)
  }
}
