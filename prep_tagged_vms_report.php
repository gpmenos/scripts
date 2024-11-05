<?php
// File paths
$inputFilePath = '/var/www/html/esxi/incoming/tagged_vms_report.csv';
$outputFilePathTemplate = '/var/www/html/esxi/Tagged_VMs_Report_%s.csv';
$permanentFilePath = '/var/www/html/esxi/Tagged_VMs_Report.csv';
$logFilePath = '/home/pulsys/logs/tagged_vms_report.txt';

// Read input CSV file
$data = file($inputFilePath);
if ($data === false) {
    error_log("Failed to read input file.\n", 3, $logFilePath);
    exit("Error reading input file.");
}

// Extract the header and the timestamp
$header = array_shift($data);
$timestamp = trim(array_pop($data));
$header = str_replace("Disk Size in Bytes", "Disk Size in TB", $header);

// Prepare the data array and calculate conversions
$tagData = [];
$totalTB = 0;
foreach ($data as $line) {
    list($tag, $vm, $size) = str_getcsv($line);
    $sizeInTB = $size / 1099511627776; // Convert bytes to terabytes
    $tagData[$tag][] = [$vm, $sizeInTB];
    $totalTB += $sizeInTB;
}

// Sort the data by tag and compile output
ksort($tagData);
$outputContent = $header;
$outputContent .= $timestamp . "\n";
$allTagSummaries = "";
foreach ($tagData as $tag => $vms) {
    usort($vms, function($a, $b) {
        return strcmp($a[0], $b[0]); // Sort VMs by name
    });
    $tagTotalTB = array_sum(array_column($vms, 1));
    $tagAverageTB = $tagTotalTB / count($vms);
    foreach ($vms as $vmData) {
        $outputContent .= sprintf("%s,%s,%.2f\n", $tag, $vmData[0], $vmData[1]);
    }
    $outputContent .= sprintf("Total Tag TB: %.2f, Average Tag TB: %.2f\n", $tagTotalTB, $tagAverageTB);
    $allTagSummaries .= sprintf("Total Tag TB: %.2f, Average Tag TB: %.2f for %s\n", $tagTotalTB, $tagAverageTB, $tag);
}

// Append overall totals
$outputContent .= sprintf("Total TB: %.2f\n", $totalTB);

// Get current date and time for output filename
$currentDateTime = date('Ymd_Hi');
$outputFilePath = sprintf($outputFilePathTemplate, $currentDateTime);

// Write the output file
if (file_put_contents($outputFilePath, $outputContent) === false) {
    error_log("Failed to write output file.\n", 3, $logFilePath);
    exit("Error writing output file.");
}

// Copy the output file to the permanent report file
if (!copy($outputFilePath, $permanentFilePath)) {
    error_log("Failed to copy to permanent report file.\n", 3, $logFilePath);
    exit("Error copying to permanent report file.");
}

// Log the completion
$currentDateTimeForLog = date('Y-m-d H:i:s');
error_log("CSV processing completed successfully on $currentDateTimeForLog\n", 3, $logFilePath);
echo "CSV processing completed. Output file: $outputFilePath\n";
echo "Permanent report updated.\n";
?>
