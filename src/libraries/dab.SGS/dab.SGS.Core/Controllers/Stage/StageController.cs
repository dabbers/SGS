using dab.SGS.Core.Cards.Playing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Controllers.Stage
{
    public abstract class StageController : Controller
    {
        public TurnStages Stage { get; protected set; }
        public Player Player { get; protected set; }
        public UserPrompt Prompt { get; set; }

        public StageController(string display, TurnStages stage, Player player) : base(display)
        {
            this.Player = player;
            this.Stage = stage;
        }

        public abstract bool IsCardPlayable(PlayingCard card);

        public abstract void Play(PlayingCard card);
    }
}
