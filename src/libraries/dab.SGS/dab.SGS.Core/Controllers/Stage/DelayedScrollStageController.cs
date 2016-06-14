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
            base(display, stage, player, new Dictionary<TurnStages, TurnStages>()
                {
                    // Placing the delayed scroll. We pop after it
                    { TurnStages.Start, TurnStages.SelectTargets },
                    { TurnStages.SelectTargets, TurnStages.End },

                    // Called again to perform the judgement
                    { TurnStages.PreJudgement, TurnStages.React },

                    // If we don't have a reaction
                    { TurnStages.React, TurnStages.NoReaction },

                    // When no reaction, go to judgement
                    { TurnStages.NoReaction, TurnStages.Judgement },

                    // After judgmenet, go to end
                    { TurnStages.Judgement, TurnStages.End },

                    // Judgement was warded. Go to end.
                    { TurnStages.Reacted, TurnStages.End }
                }
            )
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
