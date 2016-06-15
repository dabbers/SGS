using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Controllers.Stage
{
    public abstract class PromptAllPlayersStageController : StageController
    {
        public PromptAllPlayersStageController(string display, TurnStages stage, Player player) : base(display, stage, player)
        {
        }
    }
}
