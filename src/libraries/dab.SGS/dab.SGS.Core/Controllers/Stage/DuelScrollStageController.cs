using dab.SGS.Core.Cards.Playing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Controllers.Stage
{
    public abstract class DuelScrollStageController : StageController
    {
        public DuelScrollStageController(TurnStages stage, Player player) : base("Duel", stage, player)
        {
        }

        public override bool IsCardPlayable(PlayingCard card)
        {
            if (this.Stage == TurnStages.Start)
            {
                if (card.IsPlayedAsWard()) return true;
            }

            return false;
        }
    }
}
