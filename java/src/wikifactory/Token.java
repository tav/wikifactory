// Public Domain (-) 2012-2014 The Wikifactory Authors.
// See the Wikifactory UNLICENSE file for details.

package wikifactory;

public class Token {
	public static boolean isValid(String token) {
		if (token == null) {
			return false;
		}
		byte[] tokenBytes = token.getBytes();
		if (tokenBytes.length != Secret.Token.length) {
			return false;
		}
		byte total = 0;
		for (int i = 0; i < tokenBytes.length; i++) {
			total |= tokenBytes[i] ^ Secret.Token[i];
		}
		return (total == 0);
	}
}
