# T-011 — echte steunlossing onderscheiden van afzet

Bronbasis `42b1daa`: geïntegreerde stijl, bijstappen en de monotone motorpasfase. De volledige terreinproef meldde één `released_overreach` bij rechts sprinten op 7,2 m/s. De strenge eis voor normale wereldvaste contacten is behouden.

## Oorzaak

De eerste afzet vanuit stilstand passeert de bereikcontrole met de lockvlag van het vorige physicsframe. Op het laatste echte steunframe is fase 0,49565 en blijft het linker contact exact op x=-0,178139 m. Op het volgende frame is het Character al werkelijk in pasvlucht: fase 0,57498, `air_kind=stride`, `supported=false` en `may_plant=false`.

Door de capsuleverplaatsing staat de nieuwe voetbasis dan op x=0,431653 m; het oude contact ligt 0,609792 m daarachter, net buiten de noodgrens van 0,606399 m (90% van Artemis-beenlengte). De controle telde dit als bereiknoodloslating voordat de gewone afzet de oude lock vrijgaf. Er was geen verschuivende steunvoet en geen extra contact. Dit verklaart waarom de feitelijke geplante enkelfout tegelijk vrijwel nul bleef.

## Minimale correctie en bewijs

De bereikbeveiliging geldt nu alleen voor een voet die in het huidige frame daadwerkelijk steun mag houden: `may_plant && locked`. Bij afzet of gewone voetwissel geeft het bestaande vrije-voetpad de lock vrij. De drempel en de beweging veranderen niet.

`procedural_contact_release_checks.gd` gebruikt de echte motor. Rechts sprinten bevat acht echte liftoffs: beide voeten vrij in de lucht, contactdrift 0 m, grootste werkelijke geplante enkelafwijking 0,000000275 m en nul noodloslatingen. Vervolgens wordt de capsule tijdens echte steun bewust twee beenlengtes zijwaarts verplaatst: exact één noodloslating blijft actief. Zo bewijst de proef zowel de normale route als de bestaande bescherming.

De ongewijzigde volledige terreinproef controleert alle acht loop-/sprintrichtingen, richtingomkeer, treden, hellingen, plafonds, afgrond, slide-/sprongvoorkeur en momentum. Resultaten staan in [contact-release-validation.txt](contact-release-validation.txt). Herhaal beide scripts met `godot --headless --path game --script res://tests/<script>.gd`.

Deze correctie verandert alleen de juiste indeling van contactverlies. Nieuwe visuele of gevoelacceptatie is hiervoor niet nodig; de gezamenlijke Character-proef blijft als geheel open voor gebruikersbeoordeling.
