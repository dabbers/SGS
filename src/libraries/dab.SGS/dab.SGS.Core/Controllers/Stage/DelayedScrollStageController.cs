using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;

namespace dab.SGS.Core.Controllers.Stage
{
    public abstract class DelayedScrollStageController : StageController
    {
        public PlayingCard DelayedScroll { get; private set; }

        public DelayedScrollStageController(string display, TurnStages stage, Player player, PlayingCard delayed) :
            base(display, stage, player)
        {
            this.DelayedScroll = delayed;
        }

        public override bool IsCardPlayable(PlayingCard card)
        {
            if (this.Stage == TurnStages.React)
            {
                if (card.IsPlayedAsWard()) return true;
            }

            return false;
        }
        
    }
}
