using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;

namespace dab.SGS.Core.Controllers.Stage
{
    /// <summary>
    /// Used to perform a list of controller actions without a real need for input from player (IE: Peach or Wine)
    /// </summary>
    public class PerformControllersStageController : StageController
    {
        public List<Controller> Controllers { get; private set; }
        public PerformControllersStageController(string display, TurnStages stage, Player player, List<Controller> controllers) : base(display, stage, player, null)
        {
            this.Controllers = controllers;
        }

        public override bool IsCardPlayable(PlayingCard card)
        {
            return false;
        }

        public override bool Perform(GameContext context)
        {
            foreach(var c in this.Controllers)
            {
                if (!c.Perform(context))
                {
                    context.StageControllers.Pop();
                    return false;
                }
            }

            context.StageControllers.Pop();
            return true;
        }

        public override void NextStage()
        {
        }

        public override void Play(PlayingCard card)
        {
            throw new NotImplementedException();
        }
    }
}
