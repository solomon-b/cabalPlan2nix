{ lib }:

{
  # Parse a plan.json file and extract package information
  parsePlanJson = planJsonPath:
    let
      planJson = lib.importJSON planJsonPath;

      installPlan = planJson."install-plan" or [];

      configuredPackages = builtins.filter
        (pkg: pkg."type" == "configured")
        installPlan;

      extractPackageInfo = pkg: {
        name = pkg."pkg-name";
        version = pkg."pkg-version";
        isLocal = (pkg."pkg-src" or {})."type" or null == "local";
        isFromHackage = (pkg."pkg-src" or {})."type" or null == "repo-tar";
        src = pkg."pkg-src" or null;
      };

      allPackageInfos = map extractPackageInfo configuredPackages;

      # Deduplicate by package name (since callHackage gets the whole package)
      uniquePackages = builtins.attrValues (
        lib.listToAttrs (
          map (pkgInfo: {
            name = pkgInfo.name;
            value = pkgInfo;
          }) allPackageInfos
        )
      );

    in
      uniquePackages;

  # Convert absolute path to relative path if possible
  makeRelativePath = baseDir: absolutePath:
    let
      # Simple path conversion - if absolutePath starts with baseDir, make it relative
      baseDirStr = toString baseDir;
      absolutePathStr = toString absolutePath;
      # Normalize base directory (remove trailing slash if present)
      normalizedBaseDir = if lib.hasSuffix "/" baseDirStr && baseDirStr != "/"
        then builtins.substring 0 (builtins.stringLength baseDirStr - 1) baseDirStr
        else baseDirStr;
      baseDirLen = builtins.stringLength normalizedBaseDir;
      # Ensure we match directory boundaries by checking the character after baseDir
      # Either it should be end of string, or a directory separator
      validPrefix = lib.hasPrefix normalizedBaseDir absolutePathStr &&
        (baseDirLen == builtins.stringLength absolutePathStr ||
         builtins.substring baseDirLen 1 absolutePathStr == "/");
    in
      if validPrefix then
        # Remove baseDir prefix and leading slash
        let
          remaining = builtins.substring baseDirLen (builtins.stringLength absolutePathStr) absolutePathStr;
          withoutLeadingSlash = if lib.hasPrefix "/" remaining then
            builtins.substring 1 (builtins.stringLength remaining) remaining
          else remaining;
          # Handle common cases like "/." -> "." and "" -> "."
          cleanPath = if withoutLeadingSlash == "" || withoutLeadingSlash == "." then
            "./."  # Use "./" instead of just "."
          else
            withoutLeadingSlash;
        in cleanPath
      else
        # Can't make relative, use as-is (this might fail but let user handle it)
        absolutePath;
}
