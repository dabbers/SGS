using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;
using dab.SGS.Core.Cards.Playing.Basics;

namespace dab.SGS.Core.Controllers.Stage
{
    public abstract class PlayerDiedStageController : StageController
    {
        public PlayerDiedStageController(string display, TurnStages stage, Player player) : base(display, stage, player, new Dictionary<TurnStages, TurnStages>()
        {
            { TurnStages.PlayerDied, TurnStages.PlayerEliminated },
            { TurnStages.PlayerEliminated, TurnStages.End },
            { TurnStages.PlayerRevived, TurnStages.End },
        })
        {
        }

        public override bool IsCardPlayable(PlayingCard card)
        {
            if (card.Owner == this.Player && card.IsPlayedAsWine()) return true;
            if (card.IsPlayedAsPeach()) return true;

            return false;
        }
    }
}
