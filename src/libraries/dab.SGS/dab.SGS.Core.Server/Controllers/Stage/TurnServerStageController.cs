using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;
using dab.SGS.Core.Cards.Playing.Basics;
using dab.SGS.Core.Controllers.Stage;
using dab.SGS.Core.Controllers.Action;

namespace dab.SGS.Core.Server.Controllers.Stage
{
    public class TurnServerStageController : TurnStageController
    {
        public TurnServerStageController(TurnStages stage, Player start) : base("Player Turn", stage, start)
        {
        }

        public override bool Perform(GameContext context)
        {
            if (this.Player.TurnStageActions.ContainsKey(this.Stage))
            {
                if (this.Player.TurnStageActions[this.Stage].Perform(context))
                {
                    return true;
                }
            }

            switch(this.Stage)
            {
                case TurnStages.Start:
                    break;
                case TurnStages.PreJudgement:
                    if (this.Player.PlayerArea.DelayedScrolls.Count >0)
                    {
                        this.Stage = TurnStages.PreDraw;

                        var card = this.Player.PlayerArea.DelayedScrolls.First();
                        this.Player.PlayerArea.DelayedScrolls.RemoveAt(0);

                        context.StageControllers.Push(new DelayedScrollServerStageController("Judgement", TurnStages.Start, this.Player, card));

                        // This tricks our gamecontext to replay the pre-judgement phase when the delayed scroll controller is done with its thing
                        // Logic flow: 
                        // Turn.Perform() -> Push Delayed Scroll On Top
                        // Delayed.Next() -> Start > SelectTarget
                        // Delayed.Perform()... blah .... contex.Pop()
                        // Turn.Next()    -> Start > PreJudgement
                        //
                        // We go Perform() (Optional PlayCard orAction()) Next() in a loop
                        this.Stage = TurnStages.Start; 
                        
                    }
                    break;
                case TurnStages.PreDraw:

                    break;
                case TurnStages.Draw:

                    break;
                case TurnStages.Play:

                    break;
                case TurnStages.PreDiscard:

                    break;
                case TurnStages.Discard:

                    break;
                case TurnStages.End:

                    break;
                default:
                    throw new Exceptions.InvalidStageException(this.Stage);
            }
            
            return true;
        }

        public override void Play(PlayingCard card)
        {
            if (!this.IsCardPlayable(card)) throw new Exceptions.InvalidCardException(card);

            if (card.IsPlayedAsAttack())
            {
                card.Context.StageControllers.Push(new AttackServerStageController(card.Owner));
            }
            else if (card.IsPlayedAsWine())
            {
                card.Context.StageControllers.Push
                (
                    new PerformControllersStageController
                    (
                        "Wine",
                        TurnStages.Start,
                        card.Owner,
                        new List<Core.Controllers.Controller>() { new LambdaController("Enable Wine", (c) => {
                            var tmp = c.StageControllers.Peek().Player;
                            tmp.WineInEffect = true;
                            tmp.WinesLeft--;
                            return true;
                        }) }
                    )
                );
            }
            else if (card.IsPlayedAsPeach())
            {
                card.Context.StageControllers.Push
                (
                    new PerformControllersStageController
                    (
                        "Wine",
                        TurnStages.Start,
                        card.Owner,
                        new List<Core.Controllers.Controller>() { new IncreaseHealthController(1) }
                    )
                );
            }
            else if (card.IsPlayedAsDelayScroll())
            {
                card.Context.StageControllers.Push
                (
                    new DelayedScrollServerStageController(card.Display, TurnStages.Start, card.Owner, card)
                );
            }
            else if (card.IsPlayedAsDuel())
            {
                card.Context.StageControllers.Push
                (
                    new DuelScrollServerStageController(TurnStages.Start, card.Owner)
                );
            }
        }
    }
}
