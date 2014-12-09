#!/bin/bash

UPLOADPATH="/export/zoneminder/uploads";

CAMERAS=($(ls ${UPLOADPATH}));

# Command variables
AWK=`which awk || "/usr/bin/awk"`;
BASENAME=`which basename || "/usr/bin/basename"`;
ECHO=`which echo || "/bin/echo"`;
FIND=`which find || "/usr/bin/find"`;
MKDIR=`which mkdir || "/bin/mkdir"`;
MV=`which mv || "/bin/mv"`;
SED=`which sed || "/bin/sed"`;

# Cycle through the cameras
for i in ${CAMERAS[@]};
do
  ${ECHO} "Sorting ftp uploads for ${i}";
  # Find the files in the UPLOAD PATH base directory to sort
  for j in `${FIND} ${UPLOADPATH}/${i} -maxdepth 1 -iname '*.jpg' -exec ${BASENAME} '{}' \;`;
  do
    # Grab the date/time string from the filename
    DTM=`${ECHO} ${j} | ${AWK} -F'_' '{print $3}'`;
    
    # Split the date/time into the individual date components
    YEAR=${DTM:0:4};
    MONTH=${DTM:4:2};
    DAY=${DTM:6:2}
    HOUR=${DTM:8:2}

    # Define the full path for sanitizing
    FILE="${UPLOADPATH}/${i}/${j}";

    # Sanitize:  (
    FILE=`${ECHO} ${FILE} | ${SED} -e 's/(/\\(/g'`;

    # Sanitize:  )
    FILE=`${ECHO} ${FILE} | ${SED} -e 's/)/\\)/g'`;

    # Make the applicable directory for the sorted file
    ${MKDIR} -p ${UPLOADPATH}/${i}/${YEAR}/${MONTH}/${DAY}/${HOUR};

    # Move the file into place
    ${MV} "${FILE}" ${UPLOADPATH}/${i}/${YEAR}/${MONTH}/${DAY}/${HOUR}/;
  done
done

# Remove any empty directories from the UPLOAD PATH
${FIND} ${UPLOADPATH} -type d -empty -delete
