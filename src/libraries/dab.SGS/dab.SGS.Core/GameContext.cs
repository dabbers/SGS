using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;
using System.Reflection;
using dab.SGS.Core.Controllers;
using dab.SGS.Core.Controllers.Stage;

namespace dab.SGS.Core
{
    public class GameContext
    {
        public static int DEFAULT_MAX_ATTACKS = 1;
        public static int DEFAULT_MAX_NONDEATHWINES = 1;

        public Player[] Players { get { return this.players.ToArray(); } }

        public List<Roles> Roles { get; set; }
        
        public TurnStages CurrentTurnStage { get { return TurnStages.Play; } set { throw new Exception("Don't set stage this way"); } }

        public Stack<Controllers.Stage.StageController> StageControllers = new Stack<Controllers.Stage.StageController>();
         
        public Player PlayerTurn { get { return null; } }

        public Deck Deck { get; protected set; }


        /// <summary>
        /// The generic holding area for events like bountiful harvest, or special abilities where a player draws n cards and picks m.
        /// </summary>
        public GenericHoldingArea HoldingArea { get; set; }

        /// <summary>
        /// Create a new game context to hold a game. This context handles the players,
        /// their turns, the turn stages, and attack stages.
        /// </summary>
        /// <param name="discardSelect">The delegate for selcting a card to discard.</param>
        public GameContext(Deck deck)
        {
            //this.DefaultDraw = new Actions.DrawAction(2);
            //this.DefaultDiscard = new Actions.ReduceHandsizeDiscardAction();
            this.Roles = new List<Core.Roles>();
            //this.CurrentPlayStage = new PlayingCardStageTracker()
            //{
            //    Stage = TurnStages.End
            //};
            //this.PreviousStages = new Stack<PlayingCardStageTracker>();

            if (null != deck)
            {
                foreach (var card in deck.AllCards)
                {
                    card.Context = this;
                }
            }

            this.Deck = deck;
        }

        public bool IsPlayPhase()
        {
            return this.StageControllers.Peek().Stage == TurnStages.Play && this.StageControllers.Peek() is TurnStageController;
        }

        public bool IsAttackPhase()
        {
            return this.StageControllers.Peek() is AttackStageController;
        }

        public bool IsPhaseDuringAttack(TurnStages stage)
        {
            return this.IsAttackPhase() && this.StageControllers.Peek().Stage == stage;
        }


        protected List<Player> players = new List<Player>();
    }
}
