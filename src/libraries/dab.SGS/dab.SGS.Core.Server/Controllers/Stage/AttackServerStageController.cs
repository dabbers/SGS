using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;
using dab.SGS.Core.Cards.Playing.Basics;
using dab.SGS.Core.Controllers.Stage;

namespace dab.SGS.Core.Server.Controllers.Stage
{
    public class AttackServerStageController : AttackStageController
    {
        public AttackServerStageController(Player attacker) : base(attacker)
        {
            this.Stage = TurnStages.SelectTargets;
        }

        public AttackServerStageController(string display, TurnStages stage, Player player, Dictionary<TurnStages, TurnStages> transitions) : base(stage, player, transitions)
        {
        }
        

        public override bool Perform(GameContext context)
        {
            switch (this.Stage)
            {
                case TurnStages.SelectTargets:

                    break;
                case TurnStages.React:

                    break;
                case TurnStages.Reacted:

                    break;
                case TurnStages.NoReaction:

                    break;
                case TurnStages.End:

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
