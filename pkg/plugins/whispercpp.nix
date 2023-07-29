{ lib
, buildPythonPackage
, fetchPypi
, setuptools
, setuptools-scm
, wheel
}:

buildPythonPackage rec {
  pname = "whispercpp";
  version = "0.0.17";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-F0osguDue8xMITAWM9+G195JOV2B2UVam+37DHkIE94=";
  };

  nativeBuildInputs = [
    setuptools
    setuptools-scm
    wheel
  ];

  pythonImportsCheck = [ "whispercpp" ];

  meta = with lib; {
    description = "";
    homepage = "https://pypi.org/project/whispercpp/";
    license = licenses.asl20;
    maintainers = with maintainers; [ chayleaf ];
  };
}
