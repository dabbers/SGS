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
        public UserPrompt Prompt { get; protected set; }

        public StageController(string display, TurnStages stage, Player player, Dictionary<TurnStages, TurnStages> transitions) : base(display)
        {
            this.transitions = transitions;
            this.Player = player;
            this.Stage = stage;
        }

        public virtual void NextStage()
        {
            if (!this.transitions.ContainsKey(this.Stage)) throw new Exceptions.InvalidStageException(this.Stage);

            this.Stage = this.transitions[this.Stage];
        }

        public abstract bool IsCardPlayable(PlayingCard card);

        public abstract void Play(PlayingCard card);


        private Dictionary<TurnStages, TurnStages> transitions = null;
    }
}
