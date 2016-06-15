using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;

namespace dab.SGS.Core.Controllers.Stage
{
    public abstract class JudgementStageController : StageController
    {
        public Controller SuccessCheck { get; private set; }
        public JudgementStageController(Player player, Controller successCheck) : base("Judgement", TurnStages.Judgement, player)
        {
            this.SuccessCheck = successCheck;
        }

        public override bool IsCardPlayable(PlayingCard card)
        {
            return false;
        }
    }
}
