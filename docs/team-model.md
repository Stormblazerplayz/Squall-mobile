# Team model

Settings > Team model picks the model your whole team runs on, the same as the model chip on the computer.

- **By role:** the default. Chiefs on Opus, the rest on Sonnet, helpers on Haiku.
- **One model:** every teammate uses it. The little bars show how much of your plan each one uses.
- **Running now:** the model each teammate last really ran on.

Changes start from each teammate's next turn. The section only shows when Squall on the computer sends the choices
(squall-computer docs/phone-models.md).

Code: `TeamModel` in Squall/Models/TeamModel.swift and `TeamModelSection` in Squall/Views/Settings/TeamModelSection.swift.
