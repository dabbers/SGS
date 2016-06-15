using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;
using dab.SGS.Core.Cards.Playing.Basics;

namespace dab.SGS.Core.Controllers.Stage
{
    public class PlayerDiedStageController : StageController
    {
        public PlayerDiedStageController(string display, TurnStages stage, Player player) : base(display, stage, player)
        {
        }

        /*
         *         {
            { TurnStages.PlayerDied, TurnStages.PlayerEliminated },
            { TurnStages.PlayerEliminated, TurnStages.End },
            { TurnStages.PlayerRevived, TurnStages.End },
        }
        */
        public override bool IsCardPlayable(PlayingCard card)
        {
            if (card.Owner == this.Player && card.IsPlayedAsWine()) return true;
            if (card.IsPlayedAsPeach()) return true;

            return false;
        }

        public override bool Perform(GameContext context)
        {
            switch(this.Stage)
            {
                case TurnStages.PlayerDied:

                    break;
                case TurnStages.PlayerEliminated:

                    break;
                case TurnStages.PlayerRevived:

                    break;
                case TurnStages.End:
                    var c = context.StageControllers.Pop();
                    System.Diagnostics.Debug.Assert(c == this);
                    break;
            }

            return true;
        }

        public override void Play(PlayingCard card)
        {
            throw new NotImplementedException();
        }
    }
}
