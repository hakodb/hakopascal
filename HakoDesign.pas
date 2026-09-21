{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit HakoDesign;

{$warn 5023 off : no warning about unused units}
interface

uses
  HakoPkgReg, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('HakoPkgReg', @HakoPkgReg.Register);
end;

initialization
  RegisterPackage('HakoDesign', @Register);
end.
