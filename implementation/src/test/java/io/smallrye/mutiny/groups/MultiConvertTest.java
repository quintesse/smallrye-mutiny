package io.smallrye.mutiny.groups;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.reactivestreams.Publisher;

import io.smallrye.mutiny.Multi;

public class MultiConvertTest {

    @Test
    public void testMultiConvertWithCustomConverter() {
        Multi<String> multi = Multi.createFrom().items(1, 2, 3).convert().with(m -> m.map(i -> Integer.toString(i)));
        List<String> list = multi.collectItems().asList().await().indefinitely();
        assertThat(list).containsExactly("1", "2", "3");
    }

    @Test
    public void testMultiConvertToPublisher() {
        Multi<Integer> items = Multi.createFrom().items(1, 2, 3);
        Publisher<Integer> publisher = items.convert().toPublisher();
        assertThat(items).isSameAs(publisher);
    }

    @Test
    public void testThatConverterCannotBeNull() {
        assertThrows(IllegalArgumentException.class, () -> Multi.createFrom().items(1, 2, 3).convert().with(null));
    }

    @Test
    public void testThatUpstreamCannotBeNull() {
        assertThrows(IllegalArgumentException.class, () -> new MultiConvert<>(null));
    }

}
