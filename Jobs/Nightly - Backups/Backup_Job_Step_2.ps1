$dir = 'c:\dba\step_1_output.txt'
(gc $dir) | select -skip 2 | % {
    $_ -replace "\[([^;]*\])",""
} | sc $dir


$dirs = (gc  $dir)
foreach ($i in $dirs)
{
    if (!(test-path $i))
    {new-item -path $i -itemtype directory}
}

#Remove-tem $dir
