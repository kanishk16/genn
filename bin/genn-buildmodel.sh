#!/bin/bash

# display genn-buildmodel.sh help
genn_help () {
    echo "genn-buildmodel.sh script usage:"
    echo "genn-buildmodel.sh [cdho] model"
    echo "-c            only generate simulation code for the CPU"
    echo "-d            enables the debugging mode"
    echo "-m            generate MPI simulation code"
    echo "-v            generates coverage information"
    echo "-h            shows this help message"
    echo "-o outpath    changes the output directory"
    echo "-i includepath    add additional include directories (seperated by colons)"
}

# handle script errors
genn_error () { # $1=line, $2=code, $3=message
    echo "genn-buildmodel.sh:$1: error $2: $3"
    exit "$2"
}
trap 'genn_error $LINENO 50 "command failure"' ERR

# parse command options
OUT_PATH="$PWD";
BUILD_MODEL_INCLUDE=""
GENERATOR_MAKEFILE="MakefileCUDA"
while [[ -n "${!OPTIND}" ]]; do
    while getopts "cdmvo:i:h" option; do
    case $option in
        c) GENERATOR_MAKEFILE="MakefileSingleThreadedCPU";;
        d) DEBUG=1;;
        m) MPI_ENABLE=1;;
        v) COVERAGE=1;;
        h) genn_help; exit;;
        o) OUT_PATH="$OPTARG";;
        i) BUILD_MODEL_INCLUDE="$OPTARG";;
        ?) genn_help; exit;;
    esac
    done
    if [[ $OPTIND > $# ]]; then break; fi
    MODEL="${!OPTIND}"
    let OPTIND++
done

# command options logic
if [[ -z "$GENN_PATH" ]]; then
    if [[ $(uname -s) == "Linux" ]]; then
        echo "GENN_PATH is not defined - trying to auto-detect"
        export GENN_PATH="$(readlink -f $(dirname $0)/../..)"
        echo "GENN_PATH is $GENN_PATH" 
    else
        if [[ $(uname -s) == "Darwin" ]]; then
            echo "GENN_PATH is not defined - trying to auto-detect"
            export GENN_PATH="$(cd $(dirname $0)/../.. && pwd -P)"
            echo "GENN_PATH is $GENN_PATH"
        else
            genn_error $LINENO 1 "GENN_PATH is not defined"
        fi
    fi
fi
if [[ -z "$MODEL" ]]; then
    genn_error $LINENO 2 "no model file given"
fi
pushd $OUT_PATH > /dev/null
OUT_PATH="$PWD"
popd > /dev/null
pushd $(dirname $MODEL) > /dev/null
MACROS="MODEL=$PWD/$(basename $MODEL) GENERATOR_PATH=$OUT_PATH BUILD_MODEL_INCLUDE=$BUILD_MODEL_INCLUDE"
GENERATOR=./generator
popd > /dev/null
if [[ -n "$DEBUG" ]]; then
    MACROS="$MACROS DEBUG=1";
fi

if [[ -n "$MPI_ENABLE" ]]; then
    MACROS="$MACROS MPI_ENABLE=1";
    GENERATOR="$GENERATOR"_MPI
fi

if [[ -n "$COVERAGE" ]]; then
    MACROS="$MACROS COVERAGE=1";
    GENERATOR="$GENERATOR"_COVERAGE
fi

# generate model code
make -C "$GENN_PATH/generator" -f $GENERATOR_MAKEFILE $MACROS

if [[ -n "$MPI_ENABLE" ]]; then
    cp "$GENERATOR" "$GENERATOR"_"$OMPI_COMM_WORLD_RANK"
fi

if [[ -n "$DEBUG" ]]; then
    gdb -tui --args "$GENERATOR" "$OUT_PATH"
else
    if [[ -n "$MPI_ENABLE" ]]; then
        "$GENERATOR"_"$OMPI_COMM_WORLD_RANK" "$OUT_PATH"
    else
        "$GENERATOR" "$OUT_PATH"
    fi
fi

echo "model build complete"