SOURCES = Top.v
TESTBENCH = tb.v

simulate: tb.vcd

write:
	openFPGALoader -b tangprimer20k -v --write-flash -f ../impl/pnr/MDIO.fs

gtkwave: tb.vcd
	nohup gtkwave tb.vcd

a.out:
	iverilog $(TESTBENCH) $(SOURCES)

tb.vcd: a.out
	vvp a.out
