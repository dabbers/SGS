using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Controllers.Action
{
    public delegate bool PerformFnc(GameContext context);

    /// <summary>
    /// For quick 1 off lambda functions (ie setting player properties)
    /// </summary>
    public sealed class LambdaController : Controller
    {
        public PerformFnc Function { get; private set; }
        public LambdaController(string display, PerformFnc perform) : base(display)
        {
            this.Function = perform;
        }

        public override bool Perform(GameContext context)
        {
            return this.Function(context);
        }
    }
}
