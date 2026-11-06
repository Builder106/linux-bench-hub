<?php
declare(strict_types=1);

// PTS can exit successfully after skipping a failed test. Reject incomplete
// captures before they reach either dated archives or composite-latest.xml.
function readXml(string $path): SimpleXMLElement
{
    libxml_use_internal_errors(true);
    $xml = is_file($path) ? simplexml_load_file($path, SimpleXMLElement::class, LIBXML_NONET) : false;
    if ($xml === false || $xml->getName() !== 'PhoronixTestSuite') {
        throw new RuntimeException("Missing or invalid PTS XML: $path");
    }
    return $xml;
}

try {
    if ($argc !== 2) {
        throw new RuntimeException('usage: validate-workloads.php COMPOSITE_XML');
    }
    $suite = readXml(__DIR__ . '/workload-suite.xml');
    $capture = readXml($argv[1]);
    if (count($capture->System) !== 1) {
        throw new RuntimeException('Expected exactly one captured system');
    }
    foreach ($suite->Execute as $workload) {
        $id = (string) $workload->Test;
        $arguments = (string) $workload->Arguments;
        $required = match ($id) {
            'pts/tinymembench-1.0.2' => ['Standard Memcpy' => 'MB/s', 'Standard Memset' => 'MB/s'],
            'pts/c-ray-2.0.0' => [(string) $workload->Description => 'Seconds'],
            'pts/aircrack-ng-1.3.0' => ['' => 'k/s'],
            'pts/fio-2.1.0' => [(string) $workload->Description => 'MB/s'],
            default => throw new RuntimeException("Unrecognized workload: $id"),
        };
        foreach ($required as $description => $scale) {
            $found = false;
            foreach ($capture->Result as $result) {
                if ((string) $result->Identifier !== $id || (string) $result->Arguments !== $arguments
                    || (string) $result->Description !== $description || (string) $result->Scale !== $scale) {
                    continue;
                }
                $entries = $result->Data->Entry;
                if (count($entries) !== 1) {
                    throw new RuntimeException("Expected one result entry: $id $description");
                }
                $samples = explode(':', (string) $entries[0]->RawString);
                if (count($samples) !== 3) {
                    throw new RuntimeException("Expected three samples: $id $description");
                }
                foreach (array_merge($samples, [(string) $entries[0]->Value]) as $value) {
                    if (!is_numeric($value) || !is_finite((float) $value) || (float) $value <= 0) {
                        throw new RuntimeException("Invalid measurement: $id $description");
                    }
                }
                $found = true;
            }
            if (!$found) {
                throw new RuntimeException("Missing workload result: $id $arguments $description ($scale)");
            }
        }
    }
    echo "Validated CPU, memory bandwidth, and disk I/O results\n";
} catch (Throwable $error) {
    fwrite(STDERR, 'error: ' . $error->getMessage() . "\n");
    exit(1);
}
