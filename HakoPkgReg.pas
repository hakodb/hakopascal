unit HakoPkgReg;

{ Design-time registration for the Hako Lazarus package.

  Installs THakoComponent on the "Hako" tab of the component palette.
  The Register() procedure is only invoked by the Lazarus IDE when the
  package is installed; this unit also compiles fine as a plain runtime unit
  (RegisterComponents is provided by the Classes unit in the RTL), so it can
  be built with fpc alone.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, LResources;

procedure Register;

implementation

uses
  HakoComponent;

procedure Register;
begin
  RegisterComponents('Hako', [THakoComponent]);
end;

initialization
  { Palette icon for THakoComponent (resource name = lowercase class
    name). Built from thakocomponent.xpm via lazres; replace the .xpm
    and re-run lazres to change the icon. }
  {$I thakocomponent.lrs}

end.
