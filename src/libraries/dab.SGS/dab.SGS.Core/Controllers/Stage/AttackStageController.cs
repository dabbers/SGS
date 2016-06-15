using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;
using dab.SGS.Core.Cards.Playing.Basics;

namespace dab.SGS.Core.Controllers.Stage
{
    public abstract class AttackStageController : StageController
    {
        public AttackStageController(Player attacker) : base("Attack", TurnStages.Start, attacker)
        {
        }
        public AttackStageController(TurnStages stage, Player player) : base("Attack", stage, player)
        {
        }

        public override bool IsCardPlayable(PlayingCard card)
        {
            if (this.Stage == TurnStages.React)
            {
                if (card.IsPlayedAsDodge()) return true;
                else return false;
            }

            return false;
        }

    }
}
