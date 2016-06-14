using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core
{
    public static class Extensions
    {

        public static void Shuffle<T>(this IList<T> list, Random rnd)
        {
            for (var i = 0; i < list.Count; i++)
                list.Swap(i, rnd.Next(i, list.Count));
        }

        public static void Swap<T>(this IList<T> list, int i, int j)
        {
            var temp = list[i];
            list[i] = list[j];
            list[j] = temp;
        }

        /// <summary>
        /// Returns true if the move was reset. False if we moved without resetting.
        /// Counter intuitive to how the MoveNext works.
        /// </summary>
        /// <param name="en"></param>
        /// <returns></returns>
        public static bool MoveNextReset(this IEnumerator en)
        {
            var reset = false;

            if (!en.MoveNext())
            {
                en.Reset();
                reset = true;
                en.MoveNext();
            }

            return reset;
        }
    }
}
