using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;

namespace dab.SGS.Core.Controllers.Stage
{
    public class PromptStageController : StageController
    {
        public PromptStageController(string display, TurnStages stage, Player player) : base(display, stage, player)
        {
        }

        public override bool IsCardPlayable(PlayingCard card)
        {
            if (this.Prompt.Type.HasFlag(UserPromptType.AllCards)) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.CardsPlayerHand) && card.Owner.Hand.Contains(card)) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.CardsPlayerPlayArea) && card.Owner.PlayerArea.ContainsCard(card)) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.CardsTargetHand) && card.Owner.Hand.Contains(card) && card.Owner != this.Player) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.CardsTargetPlayArea) && card.Owner.PlayerArea.ContainsCard(card) && card.Owner != this.Player) return true;

            if (this.Prompt.Type.HasFlag(UserPromptType.HoldingArea) && card.Context.HoldingArea.Cards.Contains(card)) return true;

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

                    this.Stage = TurnStages.End;
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
            throw new NotImplementedException();
        }
    }
}
