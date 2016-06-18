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
        public int AttacksRequiredForAttack = GameContext.DEFAULT_MAX_ATTACKS;

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

            /*
             * {
            { TurnStages.Start, TurnStages.PreJudgement },
            { TurnStages.PreJudgement, TurnStages.PreDraw },
            { TurnStages.PreDraw, TurnStages.Draw },
            { TurnStages.Draw, TurnStages.Play },
            { TurnStages.Play, TurnStages.PreDiscard },
            { TurnStages.PreDiscard, TurnStages.Discard },
            { TurnStages.Discard, TurnStages.End },
            { TurnStages.End, TurnStages.Start },
        }
        */

            switch (this.Stage)
            {
                case TurnStages.Start:
                    if (this.Player.Flipped)
                    {
                        this.Stage = TurnStages.End;
                    }
                    else
                    {
                        this.Stage = TurnStages.PreJudgement;
                    }

                    break;
                case TurnStages.PreJudgement:
                    if (this.Player.PlayerArea.DelayedScrolls.Count > 0)
                    {
                        var card = this.Player.PlayerArea.DelayedScrolls.First();
                        this.Player.PlayerArea.DelayedScrolls.RemoveAt(0);

                        context.StageControllers.Push(new DelayedScrollServerStageController("Judgement", TurnStages.Start, this.Player, card));
                    }
                    else
                    {
                        this.Stage = TurnStages.PreDraw;
                    }
                    break;
                case TurnStages.PreDraw:
                    this.Stage = TurnStages.Draw;
                    break;
                case TurnStages.Draw:
                    this.Player.Hand.Add(context.Deck.Draw());
                    this.Player.Hand.Add(context.Deck.Draw());

                    this.Stage = TurnStages.Play;
                    break;
                case TurnStages.Play:
                    this.Prompt = new UserPrompt(UserPromptType.CardsPlayerHand | UserPromptType.Skills | UserPromptType.CardsPlayerPlayArea);
                    this.Stage = TurnStages.Prompt;
                    break;
                case TurnStages.Prompt:
                    if (this.Prompt.Cards?.Count != 0)
                    {
                        this.Stage = TurnStages.Play;
                    }
                    else
                    {
                        this.Stage = TurnStages.PreDiscard;
                    }                    
                    break;
                case TurnStages.PreDiscard:
                    this.Stage = TurnStages.Discard;
                    break;
                case TurnStages.Discard:

                    if (this.Player.MaxHandSize < this.Player.Hand.Count)
                    {
                        int cards = this.Player.Hand.Count - this.Player.MaxHandSize;

                        context.StageControllers.Push
                        (
                            new PromptStageController
                            (
                                "Discard", 
                                TurnStages.Start, 
                                this.Player, 
                                new UserPrompt(UserPromptType.CardsPlayerHand) { MinCards = cards, MaxCards = cards } 
                            )
                        );
                    }

                    break;
                case TurnStages.End:
                    // Cleanup

                    // Reset wine/attack limits
                    this.Player.WineInEffect = false;
                    this.Player.Flipped = false;
                    this.Player.WinesLeft = 1;
                    this.Player.AttacksLeft = 1;
                    this.attacksPlayed = 0;
                    this.AttacksRequiredForAttack = GameContext.DEFAULT_MAX_ATTACKS;
                    // Move turn to next player
                    this.Player = this.Player.Right;
                    
                    // Go to beginnign of turn
                    this.Stage = TurnStages.Start;
                    break;

                case TurnStages.GameOver:
                    // What do we do here????
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
                this.AttacksRequiredForAttack += this.Prompt.Cards.Count(c => c.IsPlayedAsAttack());

                var element = (card.GetPlayedAsElement() == Elemental.None ? this.Prompt.Cards.Find(p => p.IsPlayedAsAttack() && p.GetPlayedAsElement() != Elemental.None).GetPlayedAsElement() : Elemental.None);

                if (this.attacksPlayed == this.AttacksRequiredForAttack)
                {
                    card.Context.StageControllers.Push(new AttackServerStageController(card.Owner, element));
                }

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
                        "Peach",
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

        private int attacksPlayed = 0;
    }
}
