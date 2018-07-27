$CONFIG_DIR = "C:\Users\draks\OneDrive\Documents\GitHub\UniverseSchema"

Function Generate-Cluster() {    
    $num_galaxies = Get-Random -Minimum 1 -Maximum (((Get-ChildItem -Path ($CONFIG_DIR + "\" + "galaxy_positions")).Count)-1);
    Write-Host ("Galaxies: " + $num_galaxies)
    $galaxy_positions_used = @()
    foreach ($galaxy in 1..$num_galaxies) {
        $galaxy_position = $null;
        while ($galaxy_positions_used -contains $galaxy_position -or $galaxy_position -eq $null) {
            $galaxy_posnum = Get-Random -Minimum 0 -Maximum (((Get-ChildItem -Path ($CONFIG_DIR + "\" + "galaxy_positions")).Count)-1);
            $galaxy_position = ((Get-content -Path ($CONFIG_DIR + "\galaxy_positions\" + "galaxy" + $galaxy_posnum + ".txt")));
            $galaxy_positions_used += $galaxy_position
        }
        write-host ("Galaxy Position: " + $galaxy_position)
        $num_systems = Get-Random -Minimum 1 -Maximum (((Get-ChildItem -Path ($CONFIG_DIR + "\" + "system_positions")).Count)-1);
        Write-Host ("Systems: " + $num_systems)
        $system_positions_used = @()
        foreach ($system in 0..$num_systems) {
            $system_position = $null;
            while ($system_positions_used -contains $system_position -or $system_position -eq $null) {
                $system_posnum = Get-Random -Minimum 0 -Maximum (((Get-ChildItem -Path ($CONFIG_DIR + "\" + "system_positions")).Count)-1);
                $system_position = ((Get-content -Path ($CONFIG_DIR + "\system_positions\" + "system" + $system_posnum + ".txt")));
                $system_positions_used += $system_position
            }
            write-host ("System Position: " + $system_position)
            $num_stars = Get-Random -Minimum 0 -Maximum (((Get-ChildItem -Path ($CONFIG_DIR + "\" + "star_positions")).Count)-1)
            Write-Host ("Stars: " + $num_stars)
            $star_positions_used = $null; $star_positions_used = @();
            if ($num_stars -ne 0) {
                foreach ($star in 1..$num_stars) {
                    $star_position = $null;
                    while ($star_positions_used -contains $star_position -or $star_position -eq $null) {
                        $star_posnum = Get-Random -Minimum 0 -Maximum (((Get-ChildItem -Path ($CONFIG_DIR + "\" + "star_positions")).Count)-1);
                        $star_position = ((Get-content -Path ($CONFIG_DIR + "\star_positions\" + "star" + $star_posnum + ".txt")));
                        $star_positions_used += $star_position
                    }
                    write-host ("Star Position: " + $star_position)
                }
            }
            $stars = Get-StarsForSystem -num_stars $num_stars -coords $star_positions_used
            foreach ($line in $stars) {
                Write-Host $line
            }
            $num_planets = Get-Random -Minimum 0 -Maximum 6
            Write-Host ("Planets: " + $num_planets)
            $planet_positions_used = @();
            if ($num_planets -ne 0) {
                foreach ($planet in 1..$num_planets) {
                    $planet_position = $null;
                    while ($planet_positions_used -contains $planet_position -or $planet_position -eq $null) {
                        $planet_posnum = Get-Random -Minimum 0 -Maximum (((Get-ChildItem -Path ($CONFIG_DIR + "\" + "planet_positions")).Count)-1);
                        $planet_position = ((Get-content -Path ($CONFIG_DIR + "\planet_positions\" + "Planet" + $planet_posnum + ".txt")));
                        $planet_positions_used += $planet_position
                    }
                    write-host ("Planet Position: " + $planet_position)
                }
                $planets = Get-PlanetsForSystem -num_planets $num_planets -planet_coords $planet_positions_used -stars $stars
                Write-Host $planets
            }
        }
    }
}

Function Get-Distance($sx, $sz, $dx, $dz) {
    $pow1 = [Math]::pow($sx-$dx,2)
    $pow2 = [Math]::pow($sz-$dz,2)
    $distance = [Math]::Sqrt( ($pow1 *2) + $pow2)
}


Function Get-PlanetsForSystem($num_planets, $planet_coords, $stars) {
    $planets = Get-Templates -type planet
    $winners = @()
    foreach ($coord in $planet_coords) {
        $x = $coord.split(":")[0]
        $z = $coord.split(":")[1]
        $zone = Get-ZoneFromStars -stars $stars -x $x -z $z
        $to_consider = $planets|where { $_.planetZone -eq $zone }
        $to_consider_duplicates = @();
        foreach ($template in $to_consider) {
            $count = 0;
            while ($count -le $template.weighting) {
                $to_consider_duplicates += $template
                $count++;
            }
        }
        $random = Get-Random -Minimum 0 -Maximum ($to_consider_duplicates.count)
        $planet = ($to_consider_duplicates[$random]).PSOBject.Copy()
        $planet|Add-Member -MemberType NoteProperty -Name PosX -Value ($x)
        $planet|Add-Member -MemberType NoteProperty -Name PosZ -Value ($z)
        $winners += $planet
    } 
    return $planet
}

Function Get-ZoneFromStars($stars, $x,$z) {
        foreach ($star in $stars) {
            $zones += Get-ZoneForStar -star $star -x $x -z $z
        }
        if ($zone -contains "UNINHABITABLE_TOOCLOSE") {
            return "UNINHABITABLE_TOOCLOSE";
        } else {
            if ($zone -contains "HABITABLE_HOT") {
                return "HABITABLE_HOT";
            } else {
                if ($zone -contains "HABITABLE_IDEAL") {
                     return "HABITABLE_IDEAL";
                } else {
                    if ($zone -contains "HABITABLE_COLD") {
                        return "HABITABLE_COLD";
                    } else {
                        return "UNINHABITABLE_TOOFAR";
                    }
                }
            }
        }
}

Function Get-ZoneForStar($star, $x, $z) {
    $distanceFrom = Get-Distance -sx $star.posX -sz $star.posZ -dx $x -dz $z
    if ($distance -le $star.habitableTooHotMin) { return "UNINHABITABLE_TOOCLOSE"; }
    if ($distance -le $star.habitableIdealMin) { return "HABITABLE_HOT"; }
    if ($distance -le $star.habitableColdMin) { return "HABITABLE_IDEAL"; }
    if ($distance -le $star.uninhabitableTooColdMin) { return "HABITABLE_COLD"; }
    return "UNINHABITABLE_TOOFAR";
}

Function Get-StarsForSystem($num_stars, $coords) {
    return Get-ObjectMatches -num_objects $num_stars -coords $coords -type star
}

Function Get-ObjectMatches($num_objects, $coords, $type) {
    Write-Host ("" + $num_objects + "," + $coords + "," + $type)
    if ($num_objects -eq 0) { return; }
    $templates = Get-Templates -type $type
    $to_consider = @()
    $to_return = @()
    foreach ($template in $templates) {
        if ($template.maxStarsInSystem -ge $num_stars) {
            $to_consider += $template
        }
    }
    $to_consider_duplicates = @();
    foreach ($item in $to_consider) {
        $count = 0;
        while ($count -le $item.weighting) {
            $to_consider_duplicates += $item
            $count++;
        }
    }
    $winners = @();
    foreach ($s in 0..($num_stars)) {
        $random = Get-Random -Minimum 0 -Maximum (($to_consider_duplicates.Count-1));
        $winners += $to_consider_duplicates[$random]
    }

    $count = 0;
    foreach ($winner in $winners) {
        $winnerCopy = $winner.PSObject.copy()
        $winnerCopy|Add-Member -MemberType NoteProperty -Name PosX -Value ($coords[$count]).split(":")[0]
        $winnerCopy|Add-Member -MemberType NoteProperty -Name PosZ -Value ($coords[$count]).split(":")[1]
        $to_return += $winnerCopy
    }
    return $to_return
}

Function Get-Templates($type) {
    $objects = @();
    foreach ($item in Get-ChildItem -Path ($CONFIG_DIR + "\" + $type + "_definitions")) {
        $content = get-content -Path $item.fullName
        $object = New-Object -TypeName PSOBject
        $object|Add-Member -MemberType NoteProperty -Name Name -Value ($item.baseNAme)
        foreach ($line in $content) {
            if ($line -notlike "*:*") { continue; }
            $object|Add-Member -MemberType NoteProperty -name ($line.split(":")[0]) -Value ($line.split(" ")[1])
        }
        $objects += $object
    }
    return $objects;
}
$cluster = Generate-Cluster
