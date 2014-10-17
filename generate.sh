#!/bin/bash

# Burkina Faso
./map.sh -c africa -a burkina-faso -n "Burkina Faso" -i 53267593
./topo.sh -a burkina-faso -n "Burkina Faso topo" -c BFA -m 20130001

# Ivory Coast
./map.sh -c africa -a ivory-coast -n "Ivory Coast" -i 73267593
./topo.sh -a ivory-coast -n "Ivory Coast topo" -c CIV -m 20140001
