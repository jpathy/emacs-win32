try {
    Write-Host "Updating PKGBUILD for emacs with most recent commit..." -NoNewline;
    # parse atom link to extract latest commit details.
    $atomResp = Invoke-RestMethod -Uri "https://git.savannah.gnu.org/cgit/emacs.git/atom/?h=master";
    $commit = $atomResp[0].id;
    $pkgdate = ($atomResp[0].updated -Split 'T')[0] -replace '-';
    $fileName = "emacs-${commit}.tar.gz";
    # Download file
    Invoke-WebRequest -Uri "https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs-${commit}.tar.gz" -OutFile $fileName;
    $sha256sum = (Get-FileHash -Path $fileName -Algorithm SHA256).Hash;
    # Get the latest emacs version from repo.
    $pkgver = ((Invoke-WebRequest -Uri "https://git.savannah.gnu.org/cgit/emacs.git/plain/configure.ac?id=${commit}").Content |
                Select-String "`nAC_INIT\(GNU Emacs,\s*([0-9\.]*?)\s*, ").Matches.Groups[1].Value;
    # Update PKGBUILD.
    (Get-Content -Raw -Path "./PKGBUILD.template") `
                                -creplace "(?m)^(\s*pkgver=)(?:.*)", "`${1}${pkgver}" `
                                -creplace "(?m)^(\s*pkgrel=)(?:.*)", "`${1}${pkgdate}" `
                                -creplace "(?m)^(\s*pkgrev=)(?:.*)", "`${1}${commit}" `
                                -creplace "(?m)^(\s*sha256sums=)(?:.*)", "`${1}('${sha256sum}')" |
        Set-Content -NoNewline -Path "./PKGBUILD";
    Write-Host "Done.";
    # Only works on github actions.
    if ($env:GITHUB_ACTIONS -eq "true") {
        Write-Output "::group::makepkg-mingw";
        msys2 -c 'dos2unix ./PKGBUILD; makepkg-mingw -sCcL --noconfirm --noprogressbar';
        $pkgout = (msys2 -c 'cygpath -w $(makepkg-mingw --packagelist)').Trim();
        Write-Output "PKGOUT=$pkgout" >> $env:GITHUB_ENV;
        Write-Output "PKGDATE=$pkgdate" >> $env:GITHUB_ENV;
        Write-Output "COMMIT_URL=https://git.savannah.gnu.org/cgit/emacs.git/commit/?id=${commit}" >> $env:GITHUB_ENV;
        Write-Output "::endgroup::";
    }
}
catch [System.Net.Http.HttpRequestException] {
    Write-Information "Failed to fetch: $($_.Exception.Response.RequestMessage.RequestUri.AbsoluteUri)`n" -InformationAction Continue;
    throw $_;
}
catch {
    Write-Information "Bug in script" -InformationAction Continue;
    throw $_;
}