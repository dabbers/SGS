using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;

namespace dab.SGS.Core.Controllers.Stage
{
    public delegate bool IsCardPlayable(PlayingCard card);

    public class PromptStageController : StageController
    {
        public PromptStageController(string display, TurnStages stage, Player player, UserPrompt prompt, IsCardPlayable icp = null) : base(display, stage, player)
        {
            this.Prompt = prompt;
            this.icp = icp;
        }

        public override bool IsCardPlayable(PlayingCard card)
        {
            // Validate the card comes from the respective area
            if (this.Prompt.Type.HasFlag(UserPromptType.AllCards)) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.CardsPlayerHand) && card.Owner.Hand.Contains(card)) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.CardsPlayerPlayArea) && card.Owner.PlayerArea.ContainsCard(card)) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.CardsTargetHand) && card.Owner.Hand.Contains(card) && card.Owner != this.Player) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.CardsTargetPlayArea) && card.Owner.PlayerArea.ContainsCard(card) && card.Owner != this.Player) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.HoldingArea) && card.Context.HoldingArea.Cards.Contains(card)) return true;


            if (this.icp != null)
                return this.icp(card);
            else
                return false;
        }

        public override bool Perform(GameContext context)
        {
            switch (this.Stage)
            {
                case TurnStages.Start:


                    this.Stage = TurnStages.Prompt;
                    break;
                case TurnStages.Prompt:
                    var passed = false;

                    if (this.Prompt.Cards.Count >= this.Prompt.MinCards && this.Prompt.Cards.Count <= this.Prompt.MaxCards)
                    {
                        passed = true;
                    }
                    else if (this.Prompt.Targets.Count >= this.Prompt.MinTargets && this.Prompt.Targets.Count <= this.Prompt.MaxTargets)
                    {
                        passed = true;
                    }
                    else
                    {
                        if (this.Prompt.Targets.Count > 0)
                        {
                            passed = true;

                            foreach(var t in this.Prompt.Targets)
                            {
                                var dist = this.Player.GetDistance(t);
                                if (dist < this.Prompt.MinRange || dist > this.Prompt.MaxRange)
                                {
                                    passed = false;
                                }
                            }
                        }
                    }

                    if (passed)
                    {
                        this.Stage = TurnStages.End;
                    }
                    break;
                case TurnStages.End:

                    context.StageControllers.Pop();
                    context.StageControllers.Peek().Prompt = this.Prompt;
                    break;
            }

            return true;
        }

        public override void Play(PlayingCard card)
        {
            if (this.IsCardPlayable(card))
                this.Prompt.Cards.Add(card);
        }

        private IsCardPlayable icp;
    }
}
