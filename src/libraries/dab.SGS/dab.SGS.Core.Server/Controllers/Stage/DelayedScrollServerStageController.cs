using dab.SGS.Core.Controllers.Stage;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;

namespace dab.SGS.Core.Server.Controllers.Stage
{
    public class DelayedScrollServerStageController : DelayedScrollStageController
    {
        public DelayedScrollServerStageController(string display, TurnStages stage, Player player, PlayingCard delayed) : base(display, stage, player, delayed)
        {
        }

        public override bool Perform(GameContext context)
        {
            /*
             *                 {
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
                */
            throw new NotImplementedException();
        }

        public override void Play(PlayingCard card)
        {
            throw new NotImplementedException();
        }
    }
}
