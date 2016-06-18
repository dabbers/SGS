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
        public int DodgesRequired { get; set; }
        public Elemental Elemental { get; set; }
        public int DamageCaused { get; set; }

        public AttackStageController(Player attacker, Elemental element, int damage = 1, int dodgesRequired = 1) : base("Attack", TurnStages.Start, attacker)
        {
            this.DodgesRequired = dodgesRequired;
            this.Elemental = element;
            this.DamageCaused = damage;
        }


        public override bool IsCardPlayable(PlayingCard card)
        {
            return false;
        }

    }
}
