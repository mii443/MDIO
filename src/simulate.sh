#!/bin/sh

iverilog tb.v Top.v
vvp a.out
nohup gtkwave tb.vcd
