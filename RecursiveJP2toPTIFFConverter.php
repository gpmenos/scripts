<?php
// Configuration variables
$dryRun = 0; // 0 for real run, 1 for dry-run
$startPath = '/data/jp2s';
$startSubDirPartialString = 'pudl01';
$displayResultsInterval = 100;
$logFile = '/path/to/file.log';

// Initialize counters
$numConverted = 0;
$numAlreadyConverted = 0;
$numDirectoriesProcessed = 0;

// Open the log file
$logHandle = fopen($logFile, 'a');

// Write a message to the log and optionally to the console
function logMessage($message, $toConsole = false) {
    global $logHandle;
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "$timestamp - $message\n";
    fwrite($logHandle, $logEntry);
    if ($toConsole) {
        echo $logEntry;
    }
}

// Process directories and files recursively
function processDirectory($directory) {
    global $startSubDirPartialString, $dryRun, $numConverted, $numAlreadyConverted, $numDirectoriesProcessed, $displayResultsInterval;

    $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($directory));
    foreach ($iterator as $file) {
        if ($file->isDir()) continue;

        $filePath = $file->getPathname();
        $filename = $file->getFilename();

        // Check if the file is a jp2 file
        if (pathinfo($filename, PATHINFO_EXTENSION) === 'jp2') {
            $baseName = pathinfo($filename, PATHINFO_FILENAME);
            $tifPath = $file->getPath() . '/' . $baseName . '.tif';
            $ptiffPath = $file->getPath() . '/' . $baseName . '.tiff';

            // Check if this directory matches the partial string
            if (strpos($file->getPath(), $startSubDirPartialString) === false) continue;

            // Check if the PTIFF version already exists
            if (file_exists($ptiffPath)) {
                $numAlreadyConverted++;
            } else {
                // Convert the JP2 to PTIFF
                if (!$dryRun) {
                    $command = "/path/convert-jp2-to-pyramidal-tiff.sh " . escapeshellarg($filePath);
                    $output = shell_exec($command);
                    $exitStatus = $output ? 0 : 1; // Assuming the script outputs something on success

                    if ($exitStatus === 0) {
                        $numConverted++;
                        unlink($tifPath); // Delete the intermediary TIF file
                    }
                } else {
                    $numConverted++; // Simulating conversion
                }
            }

            // Log the results after every X number of files examined
            if (($numConverted + $numAlreadyConverted) % $displayResultsInterval === 0) {
                logMessage("Processed $displayResultsInterval files: $numConverted converted, $numAlreadyConverted already converted.", true);
            }
        }
    }
    $numDirectoriesProcessed++;
}

// Start processing from the initial directory
processDirectory($startPath);

// Close log file
fclose($logHandle);

// Display final results
logMessage("Conversion complete. Directories processed: $numDirectoriesProcessed, JP2 images converted: $numConverted, JP2s already converted: $numAlreadyConverted", true);
?>

