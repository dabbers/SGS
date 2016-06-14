using dab.SGS.Core.Controllers.Stage;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Controllers.Action
{
    public class ReduceHealthController : Controller
    {
        public int DecreaseBy { get; private set; }
        public ReduceHealthController(int decBy) : base("Decrease health by " + decBy.ToString())
        {
            if (decBy < 0) throw new ArgumentOutOfRangeException("decBy", decBy, "Value cannot be negative");
            this.DecreaseBy = decBy;
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
            p.CurrentHealth -= this.DecreaseBy;

            if (p.CurrentHealth < 1)
            {
                return false;
            }

            return true;
        }

    }
}
