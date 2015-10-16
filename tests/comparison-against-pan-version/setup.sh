#!/bin/bash

echo "Info: this setup script must be sourced from its own directory"
export PATH=$PATH:$(pwd)/bin:$(pwd)/pan15-bin
export PERL5LIB=$PERL5LIB:$(pwd)/TextAnalytics-lib
