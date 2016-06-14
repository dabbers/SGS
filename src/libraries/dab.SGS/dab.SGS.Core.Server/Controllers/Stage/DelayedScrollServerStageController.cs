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
            throw new NotImplementedException();
        }

        public override void Play(PlayingCard card)
        {
            throw new NotImplementedException();
        }
    }
}
