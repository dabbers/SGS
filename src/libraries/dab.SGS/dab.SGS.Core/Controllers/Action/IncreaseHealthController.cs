using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Controllers.Action
{
    public class IncreaseHealthController : Controller
    {
        public int IncreaseBy { get; private set; }
        public IncreaseHealthController(int incBy) : base("Decrease health by " + incBy.ToString())
        {
            if (incBy < 0) throw new ArgumentOutOfRangeException("decBy", incBy, "Value cannot be negative");
            this.IncreaseBy = incBy;
        }

        /// <summary>
        /// Perform health decrease on the current stage's player.
        /// </summary>
        /// <param name="context"></param>
        /// <returns>True if alive, false if died.</returns>
        public override bool Perform(GameContext context)
        {
            var stage = context.StageControllers.Peek();
            var p = stage.Player;
            p.CurrentHealth += this.IncreaseBy;

            if (p.CurrentHealth < 1)
            {
                return false;
            }

            return true;
        }

    }
}
