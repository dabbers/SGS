using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;
using dab.SGS.Core.Cards.Playing.Basics;
using dab.SGS.Core.Controllers.Stage;
using dab.SGS.Core;

namespace dab.SGS.Core.Server.Controllers.Stage
{
    public class AttackServerStageController : AttackStageController
    {
        public AttackServerStageController(Player attacker, Elemental element) : base(attacker, element)
        {
        }
        

        public override bool Perform(GameContext context)
        {
            // Specific to Attack controller.
            if (this.Player.TurnStageActions.ContainsKey(TurnStages.DuringAttack))
            {
                if (this.Player.TurnStageActions[TurnStages.DuringAttack].Perform(context))
                {
                    return true;
                }
            }
            // Let them figure it out
            if (this.Player.TurnStageActions.ContainsKey(this.Stage))
            {
                if (this.Player.TurnStageActions[this.Stage].Perform(context))
                {
                    return true;
                }
            }

            switch (this.Stage)
            {
                case TurnStages.Start:
                    this.Stage = TurnStages.Start;
                    this.Prompt = null;

                    break;
                case TurnStages.SelectTargets:
                    if (this.Prompt == null)
                    {
                        this.Prompt = new UserPrompt(UserPromptType.TargetRangeMN)
                        {
                            MinRange = 1,
                            MaxRange = this.Player.GetAttackRange(),
                            MinTargets = 1,
                            MaxTargets = 1
                        };

                        context.StageControllers.Push(new PromptStageController("Target", TurnStages.Start, this.Player, this.Prompt));
                        this.Stage = TurnStages.SelectTargets;
                    }
                    else if (this.Prompt.Targets.Count > 0)
                    {
                        // we cache this prompt becuse we'll overwrite it when accepting input from the targets
                        this.targetedPrompt = this.Prompt;
                        this.Stage = TurnStages.React;
                    }
                    else
                    {
                        this.Stage = TurnStages.End;
                    }

                    break;
                case TurnStages.React:

                    if (this.targetedPrompt.Targets.Count > 0)
                    {
                        this.Prompt = new UserPrompt(UserPromptType.CardsPlayerHand | UserPromptType.UseShieldSkill)
                        {
                            NoneOrMax = this.DodgesRequired
                        };

                        context.StageControllers.Push(new PromptStageController("Target", TurnStages.Start, this.targetedPrompt.Targets.First(), this.Prompt, this.IsCardPlayable));

                        this.Stage = TurnStages.Reacted;
                    }
                    else
                    {
                        this.Stage = TurnStages.End;
                    }
                    break;
                case TurnStages.Reacted:

                    // Due to the prompt requirement, not 0 means they choose exactly DodgesRequired
                    if (this.Prompt.Cards.Count > 0)
                    {
                        // Remove the player that just reacted
                        this.targetedPrompt.Targets.RemoveAt(0);

                        // Any more players to react?
                        if (this.targetedPrompt.Targets.Count > 0)
                        {
                            this.Stage = TurnStages.React;
                        }
                        else
                        {
                            this.Stage = TurnStages.End;
                        }
                    }
                    else
                    {
                        this.Stage = TurnStages.NoReaction;
                    }
                    break;
                case TurnStages.NoReaction:
                    // 

                    break;
                case TurnStages.End:

                    break;
            }

            return true;

        }

        public override void Play(PlayingCard card)
        {
            throw new NotImplementedException();
        }

        private UserPrompt targetedPrompt;
    }
}
