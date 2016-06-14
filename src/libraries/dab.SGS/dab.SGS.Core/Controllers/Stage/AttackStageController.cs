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
        public AttackStageController(Player attacker) : base("Attack", TurnStages.Start, attacker, new Dictionary<TurnStages, TurnStages>()
        {
            {TurnStages.Start, TurnStages.SelectTargets },
            {TurnStages.SelectTargets, TurnStages.React },
            {TurnStages.Reacted, TurnStages.End },
            {TurnStages.NoReaction, TurnStages.End },
        })
        {
        }
        public AttackStageController(TurnStages stage, Player player, Dictionary<TurnStages, TurnStages> transitions) : base("Attack", stage, player, transitions)
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
