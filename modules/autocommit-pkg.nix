{
  pkgs ? import <nixpkgs> { },
}:

pkgs.python3Packages.buildPythonApplication rec {
  pname = "autocommit";
  version = "1.0.0";

  src = pkgs.fetchFromGitHub {
    owner = "e-p-armstrong";
    repo = "autocommit";
    rev = "52e4883dd3238b83006820cd9ab0cdb16352feac";
    sha256 = "1xcxzjs2sl8bccin2r97xfkpmds155bzvb90jjd51x11y1izy40b";
  };

  # Fix Python syntax warnings (invalid escape sequences)
  postPatch = ''
    sed -i "s/\\\\ No newline/ No newline/g" autocommit.py
  '';

  propagatedBuildInputs = with pkgs.python3Packages; [
    openai
    pyyaml
  ];

  # The tool is just a script, let's wrap it
  format = "other";

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/lib/autocommit
    cp autocommit.py $out/lib/autocommit/

    # We create a wrapper that runs the script with the correct python environment
    makeWrapper ${pkgs.python3.withPackages (ps: with ps; [ openai pyyaml ])}/bin/python $out/bin/autocommit \
      --add-flags "$out/lib/autocommit/autocommit.py" \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.git ]}
  '';

  nativeBuildInputs = [ pkgs.makeWrapper ];

  meta = with pkgs.lib; {
    description = "Automatically commit in a repo and get AI to write the messages";
    homepage = "https://github.com/e-p-armstrong/autocommit";
    license = licenses.mit;
    maintainers = [ ];
  };
}
