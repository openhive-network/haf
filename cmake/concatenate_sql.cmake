# Script to concatenate SQL files at build time
# Usage: cmake -DOUTPUT_FILE=... -DINPUT_FILES="file1;file2;..." -P concatenate_sql.cmake

if(NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "OUTPUT_FILE not defined")
endif()

if(NOT DEFINED INPUT_FILES)
    message(FATAL_ERROR "INPUT_FILES not defined")
endif()

# Append input files to output file (output file should already exist)
foreach(input_file ${INPUT_FILES})
    file(READ "${input_file}" contents)
    file(APPEND "${OUTPUT_FILE}" "${contents}")
endforeach()
