import { tva } from "@gluestack-ui/utils/nativewind-utils";
import { styled } from "nativewind";
import React from "react";
import { Text as RNText, type TextProps } from "react-native";

const textStyle = tva({
	base: "text-foreground font-sans",
});

const StyledText = styled(
	React.forwardRef<TextProps, RNText>(function StyledTextInner(props, ref) {
		return <RNText {...props} ref={ref} />;
	}),
	{ className: "style" },
);

export interface ITextProps extends TextProps {
	className?: string;
}

const Text = React.forwardRef<React.ComponentRef<typeof RNText>, ITextProps>(
	function Text({ className, ...props }, ref) {
		return (
			<StyledText
				ref={ref}
				{...props}
				className={textStyle({ class: className })}
			/>
		);
	},
);

Text.displayName = "Text";

export { Text };
